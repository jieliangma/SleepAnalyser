import Foundation

struct ProcessedFrame: Sendable {
    let timestamp: Date
    let samples: [Float]
    let noiseLevel: Double
    let isVoiceActivity: Bool
}
