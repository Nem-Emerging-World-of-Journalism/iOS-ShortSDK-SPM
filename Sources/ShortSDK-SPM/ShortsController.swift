//
//  ShortsController.swift
//  JioNewsShortsSDK
//
//  Shared state + command bridge between the UIKit `ShortsView` (the public
//  SDK surface) and the SwiftUI native AVPlayer feed it hosts. The feed
//  observes the published flags for playback/mute; the wrapper reads back the
//  current brief and receives callbacks (feed loaded, share tapped).
//

import Foundation
import Combine
import UIKit
import CleverTapSDK

final class ShortsController: ObservableObject {

    // MARK: Configuration
    /// Home id used to log in (exchanged for an Authorization token).
    let hid: String
    let theme: JioShortsTheme
    let initialBriefId: String?
    /// When true, the SDK prints verbose `[JioShorts]` logs (set via `initData(debug:)`).
    let debug: Bool

    // Device info sent to the loginWeb mutation.
    private let deviceName: String
    private let deviceType = "ios"
    private let fingerprint: String

    /// Authorization token minted from `hid` via loginWeb; cached for the session.
    private var authToken: String?

    // MARK: Analytics
    let analytics: ShortsAnalytics
    private var feedLoadDate: Date?
    private var currentShortStartDate: Date?
    private var previousBrief: STBNewsBrief?
    private var viewedShortIds: Set<String> = []
    private var lastSwipe: String = "NA"
    /// Real video durations (seconds) reported by the AVPlayer, keyed by brief id.
    private var knownDurations: [String: Int] = [:]
    /// The short for the most recent share tap; used to fire `content_share_submit`.
    private var lastSharedBrief: STBNewsBrief?

    // MARK: Playback state (observed by the SwiftUI feed)
    @Published var isMuted: Bool
    @Published var isPaused: Bool = false
    @Published var isPlaybackDisabled: Bool = false

    /// The brief currently centered in the feed.
    @Published var currentBrief: STBNewsBrief?

    // MARK: Callbacks up to the UIKit layer
    var onFeedLoaded: (() -> Void)?
    var onShareTapped: ((STBNewsBrief) -> Void)?
    var onCurrentBriefChanged: ((STBNewsBrief?) -> Void)?

    init(hid: String, theme: JioShortsTheme, isMuted: Bool, initialBriefId: String?, debug: Bool = false) {
        self.hid = hid
        self.theme = theme
        self.isMuted = isMuted
        self.initialBriefId = initialBriefId
        self.debug = debug
        self.deviceName = UIDevice.current.marketingModelName
        self.fingerprint = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.analytics = ShortsAnalytics(theme: theme)
    }

    // MARK: - Debug logging

    /// Prints a line only when the SDK was initialised with `debug: true`.
    /// `@autoclosure` keeps the message-building cost at zero when debug is off.
    func log(_ message: @autoclosure () -> String) {
        guard debug else { return }
        print("🟣 [JioShorts] \(message())")
    }

    // MARK: Auth

    /// Returns a valid Authorization token, logging in with `hid` on first use
    /// and caching the result for the session.
    func token() async throws -> String {
        if let authToken = authToken, !authToken.isEmpty { return authToken }
        log("Auth: logging in with hid…")
        let session = try await GraphQLService.shared.loginWeb(
            hid: hid, deviceName: deviceName, deviceType: deviceType, fingerprint: fingerprint
        )
        let minted = session.token ?? ""
        authToken = minted
        log("Auth: token minted ✓ (session.id=\(session.id ?? "nil"))")

        // Mirror web: clevertap.profile.push({ Site: { Identity, Name } }).
        if let id = session.id, !id.isEmpty {
            analytics.userId = id
            CleverTap.sharedInstance()?.profilePush(["Identity": id, "Name": id])
        }
        return minted
    }

    // MARK: Mute (persisted)

    func toggleMute() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        UserDefaults.isShortsMuted = muted
    }

    // MARK: Playback commands (driven by the public API)

    func play() {
        guard !isPlaybackDisabled else { return }
        isPaused = false
    }

    func pause() {
        isPaused = true
    }

    func setPlaybackDisabled(_ disabled: Bool) {
        isPlaybackDisabled = disabled
        if disabled { isPaused = true }
    }

    /// True only when the current card should actually be playing.
    var shouldPlay: Bool {
        !isPaused && !isPlaybackDisabled
    }

    // MARK: - Analytics tracking

    /// Call when the first page has loaded. Fires `shorts_feed_load`.
    func recordFeedLoad(loadTime: Int, apiError: String?) {
        feedLoadDate = Date()
        log("Feed: loaded (loadTime=\(loadTime)s, apiError=\(apiError ?? "NA"))")
        analytics.feedLoad(loadTime: loadTime, apiError: apiError)
    }

    /// Reports the real video duration (seconds) from the AVPlayer for a brief.
    func recordDuration(_ seconds: Double, for briefId: String) {
        guard seconds.isFinite, seconds > 0 else { return }
        knownDurations[briefId] = Int(seconds.rounded())
    }

    /// Real player duration if known, else the API model value.
    private func duration(for brief: STBNewsBrief) -> Int {
        if let known = knownDurations[brief.id], known > 0 { return known }
        return Int(brief.video?.duration ?? 0)
    }

    /// Call when the centered short changes (or on first appearance). Fires
    /// `shorts_view` for the short being left, and tracks timing/counts.
    func recordCurrentBrief(_ brief: STBNewsBrief?, swipe: String) {
        if let prev = previousBrief {
            analytics.shortsView(item: prev, swipe: swipe, watchedTime: secondsSinceShortStart(), contentDuration: duration(for: prev))
        }
        log("Scroll: current=\(brief?.id ?? "nil") swipe=\(swipe)")
        lastSwipe = swipe
        previousBrief = brief
        currentShortStartDate = Date()
        if let id = brief?.id { viewedShortIds.insert(id) }

        currentBrief = brief
        onCurrentBriefChanged?(brief)
    }

    /// Call when the feed is dismissed. Fires the trailing `shorts_view` and `shorts_feed_exit`.
    func recordFeedExit() {
        if let prev = previousBrief {
            analytics.shortsView(item: prev, swipe: "NA", watchedTime: secondsSinceShortStart(), contentDuration: duration(for: prev))
        }
        let viewTime = feedLoadDate.map { Int(Date().timeIntervalSince($0)) } ?? 0
        log("Feed: exit (viewTime=\(viewTime)s, viewCount=\(viewedShortIds.count))")
        analytics.feedExit(viewTime: viewTime, viewCount: viewedShortIds.count)
        // Reset so a re-entry starts fresh.
        previousBrief = nil
        currentShortStartDate = nil
    }

    private func secondsSinceShortStart() -> Int {
        currentShortStartDate.map { max(0, Int(Date().timeIntervalSince($0))) } ?? 0
    }

    // MARK: - Share

    /// Records a share impression on the backend. Fire-and-forget; the result
    /// and any error are intentionally ignored. Also fires `content_share_select`.
    func tapShare(_ item: STBNewsBrief) {
        lastSharedBrief = item
        log("Share: tapped \(item.id)")
        analytics.shareSelect(item: item, swipe: lastSwipe)
        Task {
            guard let token = try? await token() else { return }
            _ = try? await GraphQLService.shared.tapShare(
                token: token, newsBriefId: item.id, contentType: item.type ?? ""
            )
        }
    }

    /// Fires `content_share_submit` for the most recently shared short. Called
    /// by the host (via `ShortsView.shareCompleted()`) when its share actually succeeds.
    func recordShareSubmitted() {
        guard let brief = lastSharedBrief ?? currentBrief else { return }
        log("Share: submitted ✓ \(brief.id)")
        analytics.shareSubmit(item: brief, swipe: lastSwipe)
    }

    // MARK: - Like / reactions

    struct LikeState: Equatable {
        var isLiked: Bool
        var count: Int
    }

    /// Per-brief like state, keyed by brief id. Local/optimistic only.
    @Published var likeStates: [String: LikeState] = [:]

    /// Current like state for a brief — seeded from the brief, then local.
    func likeState(for item: STBNewsBrief) -> LikeState {
        if let state = likeStates[item.id] { return state }
        let userReaction = (item.reactions?.userReaction ?? "").uppercased()
        let liked = userReaction.contains("LIKE") && !userReaction.contains("DISLIKE")
        return LikeState(isLiked: liked, count: item.likeCount ?? 0)
    }

    /// Toggles the like purely locally (count +1 / -1, flips green) for an
    /// instant response. The mutation is still fired in the background, but its
    /// result and any error are intentionally ignored.
    func toggleLike(_ item: STBNewsBrief) {
        let previous = likeState(for: item)
        let willLike = !previous.isLiked
        let newCount = max(0, previous.count + (willLike ? 1 : -1))
        likeStates[item.id] = LikeState(isLiked: willLike, count: newCount)
        log("Like: \(willLike ? "LIKE" : "UNLIKE") \(item.id) (count=\(newCount))")

        if willLike {
            analytics.contentLike(item: item, swipe: lastSwipe)
        } else {
            analytics.contentLikeRemove(item: item, swipe: lastSwipe)
        }

        // Fire-and-forget; UI never waits on or reacts to the response.
        Task {
            guard let token = try? await token() else { return }
            if willLike {
                _ = try? await GraphQLService.shared.addReaction(
                    token: token, newsBriefId: item.id,
                    reactionType: "Like", contentType: item.type ?? ""
                )
            } else {
                _ = try? await GraphQLService.shared.resetReaction(
                    token: token, newsBriefId: item.id,
                    contentType: item.type ?? ""
                )
            }
        }
    }
}
