import Foundation
import CoreML

final class SleepStageInferenceEngine: @unchecked Sendable {
    private let modelProvider = CoreMLModelProvider()
    private var mlModel: MLModel?
    private var modelLoaded = false

    init() {
        loadModel()
    }

    private func loadModel() {
        mlModel = modelProvider.model(for: .sleepStageClassifier)
        modelLoaded = mlModel != nil
    }

    func predict(features: FeatureVector, context: [String]) -> StagePrediction {
        if let mlModel, let result = predictWithML(mlModel, features: features, context: context) {
            return result
        }
        return predictWithRules(features: features, context: context)
    }

    private func predictWithML(_ model: MLModel, features: FeatureVector, context: [String]) -> StagePrediction? {
        guard let input = buildMLInput(features) else { return nil }
        guard let output = try? model.prediction(from: input) else { return nil }
        guard let stageStr = output.featureValue(for: "predictedStage")?.stringValue,
              let stage = SleepStage(rawValue: stageStr) else { return nil }

        var confidence = 0.75
        if let probs = output.featureValue(for: "predictedStageProbability")?.dictionaryValue {
            confidence = (probs[stageStr] as? Double) ?? 0.75
        }

        if context.contains("high_noise") { confidence *= 0.7 }

        let alternatives = SleepStage.allCases
            .filter { $0 != stage && $0 != .unknown }
            .map { ($0, (1.0 - confidence) / 4.0) }

        return StagePrediction(stage: stage, confidence: confidence, alternativeStages: alternatives)
    }

    private func buildMLInput(_ features: FeatureVector) -> MLDictionaryFeatureProvider? {
        var dict: [String: MLFeatureValue] = [:]
        let mfccNames = (0..<13).map { "mfcc_\($0)" }
        for (i, name) in mfccNames.enumerated() {
            let val: Double = i < features.mfccCoefficients.count ? Double(features.mfccCoefficients[i]) : 0
            dict[name] = MLFeatureValue(double: val)
        }
        dict["spectral_centroid"] = MLFeatureValue(double: Double(features.spectralCentroid))
        dict["spectral_rolloff"] = MLFeatureValue(double: Double(features.spectralRolloff))
        dict["spectral_flatness"] = MLFeatureValue(double: Double(features.spectralFlatness))
        dict["zero_crossing_rate"] = MLFeatureValue(double: Double(features.zeroCrossingRate))
        dict["rms_energy"] = MLFeatureValue(double: Double(features.rmsEnergy))
        dict["breathing_periodicity"] = MLFeatureValue(double: Double(features.breathingPeriodicity))
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
        let alternatives = SleepStage.allCases
            .filter { $0 != stage && $0 != .unknown }
            .map { ($0, (1.0 - confidence) / 4.0) }
        return StagePrediction(stage: stage, confidence: max(0, min(1, confidence)), alternativeStages: alternatives)
    }
}
