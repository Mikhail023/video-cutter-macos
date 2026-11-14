import AVFoundation
import AVKit
import Observation

@MainActor
@Observable
final class EditorStore {
    var project: VideoProject?
    var player: AVPlayer?
    var isImporting = false
    var errorMessage: String?

    func loadVideo(from url: URL) {
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                project = VideoProject(url: url, duration: duration.seconds)
                player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            } catch {
                errorMessage = "Не удалось открыть видео: \(error.localizedDescription)"
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
}
