import Foundation

final class ConfidenceSmoother: Sendable {
    private let alpha: Double = 0.3
    private let noiseDiscountFactor: Double = 0.5
    private let disturbanceDiscountFactor: Double = 0.3

    func smooth(rawConfidence: Double, previousSmoothed: Double, noiseLevel: Double, disturbanceActive: Bool) -> Double {
        var adjusted = rawConfidence

        if noiseLevel > -20 {
            let noiseFactor = max(noiseDiscountFactor, 1.0 - (noiseLevel + 20) / 40.0)
            adjusted *= noiseFactor
        }

        if disturbanceActive {
            adjusted *= disturbanceDiscountFactor
        }

        let smoothed = alpha * adjusted + (1.0 - alpha) * previousSmoothed
        return max(0, min(1, smoothed))
    }
}
