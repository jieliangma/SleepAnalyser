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
    private var segmentURLs: [URL] = []
    private var currentSegmentIndex = 0
    private var segmentStartTime: TimeInterval = 0

    func play(url: URL, eventId: UUID? = nil) {
        playSegments([url], eventId: eventId)
    }

    func playSegments(_ urls: [URL], eventId: UUID? = nil) {
        stop()
        segmentURLs = urls
        currentSegmentIndex = 0
        segmentStartTime = 0
        playingEventId = eventId

        duration = urls.reduce(0) { sum, url in
            sum + ((try? AVAudioPlayer(contentsOf: url))?.duration ?? 0)
        }

        playCurrentSegment()
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = 0
        playingEventId = nil
        segmentURLs = []
        currentSegmentIndex = 0
        segmentStartTime = 0
    }

    func seek(to time: TimeInterval) {
        guard !segmentURLs.isEmpty else { return }
        var accumulated: TimeInterval = 0
        for (i, url) in segmentURLs.enumerated() {
            let segDuration = (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
            if accumulated + segDuration > time {
                currentSegmentIndex = i
                segmentStartTime = accumulated
                player?.stop()
                guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
                player = p
                p.currentTime = time - accumulated
                p.play()
                currentTime = time
                return
            }
            accumulated += segDuration
        }
    }

    func toggle(url: URL, eventId: UUID? = nil) {
        if isPlaying && playingEventId == eventId {
            stop()
        } else {
            play(url: url, eventId: eventId)
        }
    }

    func toggleSegments(_ urls: [URL], eventId: UUID? = nil) {
        if isPlaying && playingEventId == eventId {
            stop()
        } else {
            playSegments(urls, eventId: eventId)
        }
    }

    private func playCurrentSegment() {
        guard currentSegmentIndex < segmentURLs.count else {
            stop()
            return
        }
        guard let p = try? AVAudioPlayer(contentsOf: segmentURLs[currentSegmentIndex]) else {
            currentSegmentIndex += 1
            playCurrentSegment()
            return
        }
        player = p
        p.play()
        isPlaying = true
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = self.segmentStartTime + player.currentTime
            if !player.isPlaying {
                self.segmentStartTime += player.duration
                self.currentSegmentIndex += 1
                if self.currentSegmentIndex < self.segmentURLs.count {
                    self.playCurrentSegment()
                } else {
                    self.stop()
                }
            }
        }
    }
}
