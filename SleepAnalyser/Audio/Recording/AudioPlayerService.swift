import Foundation
import AVFoundation

@Observable
final class AudioPlayerService: @unchecked Sendable {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playingEventId: UUID?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL, eventId: UUID? = nil) {
        stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player = p
        playingEventId = eventId
        duration = p.duration
        p.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
            if !player.isPlaying {
                self.stop()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = 0
        playingEventId = nil
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func toggle(url: URL, eventId: UUID? = nil) {
        if isPlaying && playingEventId == eventId {
            stop()
        } else {
            play(url: url, eventId: eventId)
        }
    }
}
