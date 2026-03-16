import Foundation
import CoreML

final class SleepStageInferenceEngine: @unchecked Sendable {
    private var mlModel: MLModel?
    private static let mlEnabled: Bool = {
        guard let url = Bundle.main.url(forResource: "FeatureFlags", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else { return false }
        return dict["enableMLInference"] as? Bool ?? false
    }()

    init() {
        if Self.mlEnabled {
            mlModel = CoreMLModelProvider().model(for: .sleepStageClassifier)
        }
    }

    func predict(features: FeatureVector, context: [String]) -> StagePrediction {
        if let model = mlModel, let result = predictWithML(model, features: features, context: context) {
            return result
        }
        return predictWithRules(features: features, context: context)
    }

    private func predictWithML(_ model: MLModel, features: FeatureVector, context: [String]) -> StagePrediction? {
        guard let input = buildMLInput(features),
              let output = try? model.prediction(from: input),
              let stageStr = output.featureValue(for: "predictedStage")?.stringValue,
              let stage = SleepStage(rawValue: stageStr)
        else { return nil }

        var confidence = 0.6
        if let probs = output.featureValue(for: "predictedStageProbability")?.dictionaryValue {
            confidence = (probs[stageStr] as? Double) ?? 0.6
        }
        if context.contains("high_noise") { confidence *= 0.8 }

        let rulePrediction = predictWithRules(features: features, context: context)
        if stage != rulePrediction.stage && confidence < 0.65 {
            return rulePrediction
        }

        let alternatives = SleepStage.allCases
            .filter { $0 != stage && $0 != .unknown }
            .map { ($0, (1.0 - confidence) / 4.0) }
        return StagePrediction(stage: stage, confidence: confidence, alternativeStages: alternatives)
    }

    private func buildMLInput(_ features: FeatureVector) -> MLDictionaryFeatureProvider? {
        var dict: [String: MLFeatureValue] = [:]
        for i in 0..<13 {
            let val = i < features.mfccCoefficients.count ? Double(features.mfccCoefficients[i]) : 0
            dict["mfcc_\(i)"] = MLFeatureValue(double: val)
        }
        dict["spectral_centroid"]           = MLFeatureValue(double: Double(features.spectralCentroid))
        dict["spectral_rolloff"]            = MLFeatureValue(double: Double(features.spectralRolloff))
        dict["spectral_flatness"]           = MLFeatureValue(double: Double(features.spectralFlatness))
        dict["zero_crossing_rate"]          = MLFeatureValue(double: Double(features.zeroCrossingRate))
        dict["rms_energy"]                  = MLFeatureValue(double: Double(features.rmsEnergy))
        dict["breathing_periodicity"]       = MLFeatureValue(double: Double(features.breathingPeriodicity))
        dict["breath_interval_variability"] = MLFeatureValue(double: Double(features.breathIntervalVariability))
        return try? MLDictionaryFeatureProvider(dictionary: dict)
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
