import Foundation

struct BreathingSample: Codable, Sendable {
    let timestamp: Date
    let breathsPerMinute: Double
    let regularity: Double
    let amplitude: Double
    let isValid: Bool

    init(
        timestamp: Date = Date(),
        breathsPerMinute: Double,
        regularity: Double,
        amplitude: Double,
        isValid: Bool = true
    ) {
        self.timestamp = timestamp
        self.breathsPerMinute = breathsPerMinute
        self.regularity = max(0, min(1, regularity))
        self.amplitude = amplitude
        self.isValid = isValid
    }

    var isInNormalRange: Bool {
        breathsPerMinute >= 6.0 && breathsPerMinute <= 30.0
    }
}
