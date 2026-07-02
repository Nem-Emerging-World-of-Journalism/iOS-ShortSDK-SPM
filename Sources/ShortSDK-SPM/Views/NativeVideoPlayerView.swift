//
//  NativeVideoPlayerView.swift
//  JioNewsShortsSDK
//
//  AVPlayer-backed player for the native (getNativeShorts) shorts feed.
//  Ported from the DemoShorts native feed.
//

import SwiftUI
import AVFoundation
import UIKit

struct NativeVideoPlayerView: UIViewRepresentable {
    let videoURL: URL
    let isPlaying: Bool
    let isMuted: Bool
    var onPlaybackStarted: () -> Void = {}
    /// Reports playback progress as a fraction in 0...1.
    var onProgress: (Double) -> Void = { _ in }
    /// Reports the asset's total duration in seconds, once known.
    var onDuration: (Double) -> Void = { _ in }

    func makeUIView(context: Context) -> NativePlayerContainerView {
        let view = NativePlayerContainerView()
        view.onPlaybackStarted = onPlaybackStarted
        view.onProgress = onProgress
        view.onDuration = onDuration
        view.configure(url: videoURL, muted: isMuted)
        if isPlaying { view.play() } else { view.pause() }
        return view
    }

    func updateUIView(_ uiView: NativePlayerContainerView, context: Context) {
        uiView.onPlaybackStarted = onPlaybackStarted
        uiView.onProgress = onProgress
        uiView.onDuration = onDuration
        uiView.updateURL(videoURL, muted: isMuted)
        uiView.setMuted(isMuted)
        if isPlaying { uiView.play() } else { uiView.pause() }
    }

    static func dismantleUIView(_ uiView: NativePlayerContainerView, coordinator: ()) {
        uiView.dismantle()
    }
}

final class NativePlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var currentURL: URL?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var hasFiredPlaybackStarted = false

    var onPlaybackStarted: () -> Void = {}
    var onProgress: (Double) -> Void = { _ in }
    var onDuration: (Double) -> Void = { _ in }
    private var hasFiredDuration = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        // Fit the whole video without cropping the sides (letterbox/pillarbox).
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(url: URL, muted: Bool) {
        guard currentURL != url else { return }
        teardownPlayer()
        currentURL = url
        hasFiredPlaybackStarted = false
        hasFiredDuration = false

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = muted
        p.actionAtItemEnd = .none
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        playerLayer.player = p

        // Default to fit; switch to fill (center-crop) once we know the video
        // is landscape — portrait clips stay fit (no cropping).
        playerLayer.videoGravity = .resizeAspect
        let asset = item.asset
        Task { [weak self] in
            // Report the real total duration once asset metadata is available.
            if let duration = try? await asset.load(.duration) {
                let secs = duration.seconds
                if secs.isFinite, secs > 0 {
                    await MainActor.run { self?.fireDurationOnce(secs) }
                }
            }
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let size = try? await track.load(.naturalSize),
                  let transform = try? await track.load(.preferredTransform) else { return }
            let resolved = size.applying(transform)
            let isLandscape = abs(resolved.width) > abs(resolved.height)
            await MainActor.run {
                self?.playerLayer.videoGravity = isLandscape ? .resizeAspectFill : .resizeAspect
            }
        }

        // Loop at end.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        // Detect first frame for thumbnail fade-out.
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            if time.seconds > 0.05, !self.hasFiredPlaybackStarted {
                self.hasFiredPlaybackStarted = true
                self.onPlaybackStarted()
            }
            if let duration = self.player?.currentItem?.duration.seconds,
               duration.isFinite, duration > 0 {
                let fraction = min(max(time.seconds / duration, 0), 1)
                self.onProgress(fraction)
            }
        }
    }

    func updateURL(_ url: URL, muted: Bool) {
        guard currentURL != url else { return }
        configure(url: url, muted: muted)
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    func setMuted(_ muted: Bool) { player?.isMuted = muted }

    private func fireDurationOnce(_ seconds: Double) {
        guard !hasFiredDuration else { return }
        hasFiredDuration = true
        onDuration(seconds)
    }

    func dismantle() { teardownPlayer() }

    private func teardownPlayer() {
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        endObserver = nil
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
        currentURL = nil
    }

    deinit { teardownPlayer() }
}
