import Foundation

final class SleepStageInferenceEngine: @unchecked Sendable {

    init() {}

    func predict(features: FeatureVector, context: [String]) -> StagePrediction {
        return predictWithRules(features: features, context: context)
    }

    private func predictWithRules(features: FeatureVector, context: [String]) -> StagePrediction {
        let respRate = Double(features.breathingPeriodicity)
        let regularity = 1.0 - Double(features.breathIntervalVariability)
        let energy = Double(features.rmsEnergy)
        let hasHighNoise = context.contains("high_noise")
        let hasEvents = context.contains("has_events")

        var stage: SleepStage
        var confidence: Double

        if energy < 0.005 || hasEvents {
            stage = .awake; confidence = hasEvents ? 0.5 : 0.3
        } else if respRate > 16 || energy > 0.3 {
            stage = .awake; confidence = 0.7
        } else if respRate < 10 && regularity > 0.8 {
            stage = .n3; confidence = 0.75
        } else if respRate >= 10 && respRate <= 14 && regularity > 0.6 {
            stage = .n2; confidence = 0.7
        } else if respRate > 14 && regularity < 0.4 {
            stage = .rem; confidence = 0.65
        } else if respRate >= 10 && respRate <= 15 {
            stage = .n1; confidence = 0.5
        } else {
            stage = .n2; confidence = 0.4
        }

        if hasHighNoise { confidence *= 0.7 }
        if context.contains("room_calibrated") { confidence = min(1.0, confidence * 1.15) }
        if context.contains("above_baseline") { confidence *= 0.8 }

        let noiseRMS = parseNoiseValue(context: context, prefix: "noise_rms_")
        let noiseBass = parseNoiseValue(context: context, prefix: "noise_bass_")
        if noiseRMS > 0.1 { confidence *= 0.85 }
        if noiseBass > 0.05 && (stage == .n3 || stage == .n2) { confidence *= 0.9 }
        if context.contains("noise_traffic") || context.contains("noise_motorcycle") { confidence *= 0.8 }
        if context.contains("noise_hvac") && stage.isAsleep { confidence = min(1.0, confidence * 1.05) }

        let alternatives = SleepStage.allCases
            .filter { $0 != stage && $0 != .unknown }
            .map { ($0, (1.0 - confidence) / 4.0) }
        return StagePrediction(stage: stage, confidence: max(0, min(1, confidence)), alternativeStages: alternatives)
    }

    private func parseNoiseValue(context: [String], prefix: String) -> Double {
        for flag in context where flag.hasPrefix(prefix) {
            if let val = Double(flag.dropFirst(prefix.count)) { return val }
        }
        return 0
    }
}
