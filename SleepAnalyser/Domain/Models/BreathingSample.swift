import Foundation

struct BreathingSample: Codable, Sendable {
    let timestamp: Date
    let breathsPerMinute: Double
    let regularity: Double
    let amplitude: Double

    init(
        timestamp: Date = Date(),
        breathsPerMinute: Double,
        regularity: Double,
        amplitude: Double
    ) {
        self.timestamp = timestamp
        self.breathsPerMinute = breathsPerMinute
        self.regularity = max(0, min(1, regularity))
        self.amplitude = amplitude
    }

    var isInNormalRange: Bool {
        breathsPerMinute >= 6.0 && breathsPerMinute <= 30.0
    }
}
