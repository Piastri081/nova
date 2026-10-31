import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer
import UIKit

struct PlayerScreen: View {
    let title: MediaTitle
    let startAt: Double

    @Environment(\.dismiss) private var dismiss
    @State private var lastSave = Date.distantPast

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let raw = title.streamURL, let url = URL(string: raw) {
                PlayerViewControllerRepresentable(
                    url: url,
                    startAt: startAt,
                    title: title.title
                ) { position, duration in
                    save(position: position, duration: duration)
                }
                .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Stream unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text("This title has no playable source right now.")
                )
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .novaGlass(cornerRadius: 22)
                    }
                    .accessibilityLabel("Close player")

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func save(position: Double, duration: Double) {
        guard position.isFinite, duration.isFinite, duration > 0 else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSave) > 8 else { return }
        lastSave = now

        Task {
            _ = try? await APIClient.shared.updateProgress(
                titleID: title.id,
                position: position,
                duration: duration
            )
        }
    }
}

struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    let startAt: Double
    let title: String
    let onProgress: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.updatesNowPlayingInfoCenter = true
        controller.delegate = context.coordinator

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        context.coordinator.attach(player, title: title)

        if startAt > 2 {
            player.seek(
                to: CMTime(seconds: startAt, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }

        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        coordinator.detach()
        uiViewController.player?.pause()
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private let onProgress: (Double, Double) -> Void
        private var player: AVPlayer?
        private var timeObserver: Any?

        init(onProgress: @escaping (Double, Double) -> Void) {
            self.onProgress = onProgress
        }

        func attach(_ player: AVPlayer, title: String) {
            self.player = player

            let interval = CMTime(seconds: 10, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self, let item = self.player?.currentItem else { return }
                let duration = item.duration.seconds
                let position = time.seconds
                if position.isFinite, duration.isFinite, duration > 0 {
                    self.onProgress(position, duration)
                }
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didPlayToEnd(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )

            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: title,
                MPMediaItemPropertyArtist: "Nova",
                MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
            ]
        }

        func detach() {
            if let player, let item = player.currentItem {
                let position = player.currentTime().seconds
                let duration = item.duration.seconds
                if position.isFinite, duration.isFinite, duration > 0 {
                    onProgress(position, duration)
                }
            }

            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
            NotificationCenter.default.removeObserver(self)
            player = nil
        }

        @objc
        private func didPlayToEnd(_ notification: Notification) {
            guard let item = notification.object as? AVPlayerItem else { return }
            let duration = item.duration.seconds
            if duration.isFinite, duration > 0 {
                onProgress(duration, duration)
            }
        }
    }
}
