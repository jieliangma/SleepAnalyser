import Foundation

final class SleepStageInferenceEngine: Sendable {
    func predict(features: FeatureVector, context: [String]) -> StagePrediction {
        let respRate = Double(features.breathingPeriodicity)
        let regularity = 1.0 - Double(features.breathIntervalVariability)
        let energy = Double(features.rmsEnergy)

        let hasHighNoise = context.contains("high_noise")
        let hasEvents = context.contains("has_events")

        var stage: SleepStage
        var confidence: Double

        if energy < 0.005 || hasEvents {
            stage = .awake
            confidence = hasEvents ? 0.5 : 0.3
        } else if respRate > 16 || energy > 0.3 {
            stage = .awake
            confidence = 0.7
        } else if respRate < 10 && regularity > 0.8 {
            stage = .n3
            confidence = 0.75
        } else if respRate >= 10 && respRate <= 14 && regularity > 0.6 {
            stage = .n2
            confidence = 0.7
        } else if respRate > 14 && regularity < 0.4 {
            stage = .rem
            confidence = 0.65
        } else if respRate >= 10 && respRate <= 15 {
            stage = .n1
            confidence = 0.5
        } else {
            stage = .n2
            confidence = 0.4
        }

        if hasHighNoise { confidence *= 0.7 }

        let alternatives = buildAlternatives(primary: stage, confidence: confidence)

        return StagePrediction(
            stage: stage,
            confidence: max(0, min(1, confidence)),
            alternativeStages: alternatives
        )
    }

    private func buildAlternatives(primary: SleepStage, confidence: Double) -> [(SleepStage, Double)] {
        let remaining = 1.0 - confidence
        let allStages: [SleepStage] = [.awake, .n1, .n2, .n3, .rem]
        let others = allStages.filter { $0 != primary }
        let each = remaining / Double(others.count)
        return others.map { ($0, each) }
    }
}
