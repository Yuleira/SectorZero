//
//  SplashVideoView.swift
//  EarthLord
//
//  Cinematic splash video sequence
//  Full-screen AVPlayer with ambient audio, skip button, and cross-dissolve finish
//

import SwiftUI
import AVFoundation

// MARK: - SplashVideoView

struct SplashVideoView: View {
    let onFinished: () -> Void

    @State private var opacity: Double = 1.0
    @State private var playerReady = false

    var body: some View {
        ZStack {
            // Solid black base (visible during fade & if video missing)
            Color.black.ignoresSafeArea()

            if let url = Bundle.main.url(forResource: "splash_intro", withExtension: "mp4") {
                VideoPlayerLayer(url: url) {
                    dismissWithFade()
                }
                .ignoresSafeArea()
                .onAppear { debugLog("🎥 [Splash] Attempting to load video...") }
            } else {
                // Video file missing — skip immediately, no black-screen hang
                Color.black.ignoresSafeArea()
                    .onAppear {
                        debugLog("❌ [Splash] Video file NOT found in bundle — skipping")
                        onFinished()
                    }
            }

            // Skip button — bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        dismissWithFade()
                    } label: {
                        Text(LocalizedString.actionSkip)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .opacity(opacity)
    }

    private func dismissWithFade() {
        guard opacity == 1.0 else { return } // prevent double-trigger
        withAnimation(.easeOut(duration: 0.8)) {
            opacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onFinished()
        }
    }
}

// MARK: - AVPlayer UIKit Bridge

/// UIViewRepresentable wrapping AVPlayerLayer for full-screen video playback
private struct VideoPlayerLayer: UIViewRepresentable {
    let url: URL
    let onPlaybackEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaybackEnded: onPlaybackEnded)
    }

    func makeUIView(context: Context) -> PlayerUIView {
        // Configure ambient audio so we don't interrupt user music
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let player = AVPlayer(url: url)
        player.isMuted = false

        let view = PlayerUIView(player: player)

        // Listen for playback end
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: Coordinator) {
        uiView.player?.pause()
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: Coordinator

    class Coordinator: NSObject {
        let onPlaybackEnded: () -> Void
        private var didFire = false

        init(onPlaybackEnded: @escaping () -> Void) {
            self.onPlaybackEnded = onPlaybackEnded
        }

        @objc func playerDidFinish() {
            guard !didFire else { return }
            didFire = true
            DispatchQueue.main.async { [weak self] in
                self?.onPlaybackEnded()
            }
        }
    }
}

// MARK: - PlayerUIView

/// UIView subclass with AVPlayerLayer as its backing layer
private class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Preview

#Preview {
    SplashVideoView { debugLog("Splash finished") }
}
