import Foundation

struct AudioFrame: Sendable {
    let timestamp: Date
    let samples: [Float]
    let sampleRate: Double
    let channelCount: Int

    var duration: TimeInterval {
        Double(samples.count) / sampleRate
    }

    var isEmpty: Bool {
        samples.isEmpty
    }
}
