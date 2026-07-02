//
//  ShortsView.swift
//  JioNewsShortsSDK
//
//  Public SDK surface. A UIKit `UIView` that hosts the native (AVPlayer)
//  STB shorts feed via a SwiftUI `UIHostingController`.
//
//  Public API (mirrors the Android ShortsView):
//    initData(hid:redirectSource:briefId:theme:debug:env:) -> ShortsView
//    cashShorts()
//    loadShorts()
//    playVideo(isMute:)
//    pauseVideo()
//    stopVideo()
//    muteVideo()
//    unMuteVideo()
//    getCurrentVideoUrl() -> String?
//    getCurrentVideoBrief() -> [String: Any]?
//    setOnEventListener(_:)
//    shareCompleted()
//

import UIKit
import SwiftUI
import AVFoundation
import CleverTapSDK

/// Callback for share-click and swipe events, each carrying the video object.
public protocol ShortsEventListener: AnyObject {
    /// Fired when the user taps Share on the current short.
    func onShareClick(_ brief: ShortsVideoBrief)
    /// Fired when the user swipes to a different short (the new current video).
    func onSwipe(_ brief: ShortsVideoBrief)
}

public class ShortsView: UIView {

    // MARK: - Theme constants (Int, to mirror the Android API)
    public static let THEME_LIGHT = 0
    public static let THEME_DARK = 1

    private lazy var shimmerView: ShortsShimmerView = {
        let view = ShortsShimmerView(frame: .zero, theme: self.theme)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var hostingController: UIHostingController<NativeShortsFeedView>?
    private var controller: ShortsController?

    private var hid: String = ""
    private var briefId: String?
    private var client: JioShortsClient = .myJio
    private var redirectSource: Int = 0
    private var theme: JioShortsTheme = .light
    private var isMuted: Bool = false
    private var debug: Bool = false

    internal var isSetupCompleted = false
    internal weak var eventListener: ShortsEventListener?

    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Public API

    /**
     Initialise the shorts feature. Call this first; then call `loadShorts()`
     (or `cashShorts()`) to mount and load the feed.
     - Parameters:
        - hid: The Authorization token sent to the JioNews GraphQL endpoint.
               Persisted to local storage and reused if a later call omits it.
        - redirectSource: Client/source identifier (Int).
        - briefId: Optional, Shorts item id to target.
        - theme: `THEME_LIGHT` or `THEME_DARK`. Default `THEME_LIGHT`.
        - debug: When `true`, prints verbose `[JioShorts]` lifecycle logs. Default `false`.
        - env: API environment (`.stg` or `.prod`). Default `.prod`.
     - Returns: This `ShortsView`, for chaining.
     */
    @discardableResult
    public func initData(
        hid: String,
        redirectSource: Int,
        briefId: String? = nil,
        theme: Int = ShortsView.THEME_LIGHT,
        debug: Bool = false,
        env: JioShortsEnvironment = .stg
    ) -> ShortsView {
        // Point the GraphQL client at the requested environment before any API call.
        GraphQLService.shared.endpoint = env.graphQLURL

        // Initialise CleverTap before anything else (before any API call).
        ShortsView.initCleverTapIfNeeded()

        // Reset any previous mount so a subsequent load rebuilds fresh.
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        controller = nil

        applyHid(hid)
        self.redirectSource = redirectSource
        self.client = .myJio
        self.briefId = briefId
        self.theme = (theme == ShortsView.THEME_DARK) ? .dark : .light
        self.debug = debug
        isSetupCompleted = true
        checkInitialisation()
        return self
    }

    /// Pre-loads / caches the shorts feed (mounts it so the first page begins
    /// fetching). Safe to call before `loadShorts()`.
    public func cashShorts() {
        mountIfNeeded()
    }

    /// Loads and displays the shorts feed.
    public func loadShorts() {
        mountIfNeeded()
    }

    /// Alias for `loadShorts()` (kept because the integration calls `shortload()`).
    public func shortload() {
        mountIfNeeded()
    }

    /// Registers a listener for share-click and swipe events.
    public func setOnEventListener(_ listener: ShortsEventListener) {
        self.eventListener = listener
    }

    /// Call when the host app's share completes **successfully** — e.g. from
    /// `UIActivityViewController.completionWithItemsHandler` when `completed == true`.
    /// Fires the `content_share_submit` analytics event for the short that was shared.
    public func shareCompleted() {
        controller?.recordShareSubmitted()
    }

    /// Current video URL, if any.
    public func getCurrentVideoUrl() -> String? {
        return controller?.currentBrief?.video?.url
    }

    /// Current video brief as a JSON dictionary, if any.
    public func getCurrentVideoBrief() -> [String: Any]? {
        guard let brief = controller?.currentBrief?.asShortsVideoBrief(),
              let data = try? JSONEncoder().encode(brief),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    // MARK: - Playback controls

    /// Play the current video.
    /// - Parameter isMute: mute while playing. Default `false`.
    public func playVideo(isMute: Bool = false) {
        controller?.setMuted(isMute)
        controller?.play()
    }

    /// Pause the current video.
    public func pauseVideo() {
        controller?.pause()
    }

    /// Stop the current video.
    public func stopVideo() {
        controller?.pause()
    }

    /// Mute the current video.
    public func muteVideo() {
        controller?.setMuted(true)
    }

    /// Unmute the current video.
    public func unMuteVideo() {
        controller?.setMuted(false)
    }

    // MARK: - Internal helpers

    // CleverTap credentials — mirrors web `clevertap.init(CLEVERTAP_ID, "8R5-4K5-466Z")`.
    // iOS needs (accountID, token); set the Account ID to the CLEVERTAP_ID value.
    private static let cleverTapAccountId = "8R5-4K5-466Z" //Staging TEST-9R5-4K5-466Z  ----  Prod 8R5-4K5-466Z
    private static let cleverTapToken = "534-52b" //Staging TEST-534-52c ----  Prod 534-52b

    private static var didInitCleverTap = false

    /// Initialises CleverTap once per process (mirrors `clevertap.init(...)`).
    private static func initCleverTapIfNeeded() {
        guard !didInitCleverTap else { return }
        didInitCleverTap = true
        CleverTap.setDebugLevel(CleverTapLogLevel.off.rawValue) // silence CleverTap logging in production
        CleverTap.setCredentialsWithAccountID(cleverTapAccountId, andToken: cleverTapToken)
        _ = CleverTap.sharedInstance()
    }

    /// `hid` carries the Authorization token. When provided it is used and
    /// persisted; when omitted, the last saved value is reused.
    private func applyHid(_ hid: String?) {
        if let hid = hid, !hid.isEmpty {
            self.hid = hid
            UserDefaults.hid = hid
        } else if self.hid.isEmpty, let stored = UserDefaults.hid {
            self.hid = stored
        }
    }

    private func mountIfNeeded() {
        guard isSetupCompleted else {
            return
        }
        guard hostingController == nil else { return }
        setupBaseView()
    }

    // Internal playback hooks (not part of the public client API).
    internal func startVideo() {
        controller?.play()
    }

    internal func setPlaybackDisable(_ isDisable: Bool = false) {
        controller?.setPlaybackDisabled(isDisable)
    }

    internal func cleanup() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        controller = nil
        removeObservers()
    }
}

// MARK: - Setup

extension ShortsView {

    private func setupBaseView() {
        checkInitialisation()

        if let isShortsMuted = UserDefaults.isShortsMuted {
            isMuted = isShortsMuted
        } else {
            UserDefaults.isShortsMuted = false
            isMuted = false
        }

        self.backgroundColor = (theme == .dark) ? .black : .white

        // Allow audio with the silent switch on, like other shorts players.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        setupFeed()
        setupShimmerView()
        addObservers()
    }

    private func checkInitialisation() {
        if hid.isEmpty {
            fatalError(SDKInitializationError.hidEmpty.message)
        }

        let clientPackageName = Bundle.main.bundleIdentifier
        if !(clientPackageName == "com.jio.myjio" || clientPackageName == "com.jio.shorts" || clientPackageName == "com.jio.media.jioxpressnews" || clientPackageName == "org.cocoapods.demo.jionews-shortssdk-cocoapod-Example" || clientPackageName == "com.jio.staging.myjio") {
            fatalError(SDKInitializationError.invalidClient.message)
        }
    }

    private func setupFeed() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil

        let controller = ShortsController(
            hid: hid,
            theme: theme,
            isMuted: isMuted,
            initialBriefId: briefId,
            debug: debug
        )
        controller.onFeedLoaded = { [weak self] in
            self?.stopShimmerView()
        }
        controller.onShareTapped = { [weak self] brief in
            self?.eventListener?.onShareClick(brief.asShortsVideoBrief())
        }
        controller.onCurrentBriefChanged = { [weak self] brief in
            guard let self = self else { return }
            self.isMuted = self.controller?.isMuted ?? false
            if let brief = brief {
                self.eventListener?.onSwipe(brief.asShortsVideoBrief())
            }
        }
        self.controller = controller

        let feed = NativeShortsFeedView(controller: controller)
        let host = UIHostingController(rootView: feed)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = (theme == .dark) ? .black : .white
        insertSubview(host.view, at: 0)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        self.hostingController = host
    }

    private func setupShimmerView() {
        addSubview(shimmerView)

        NSLayoutConstraint.activate([
            shimmerView.topAnchor.constraint(equalTo: self.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
        ])

        startShimmerView()
    }

    private func startShimmerView() {
        shimmerView.startShimmer()
        shimmerView.isHidden = false
    }

    private func stopShimmerView() {
        shimmerView.stopShimmer()
        shimmerView.isHidden = true
    }

    internal func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    internal func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc internal func appBecomeActive() {
    }

    @objc internal func appResignActive() {
    }
}
