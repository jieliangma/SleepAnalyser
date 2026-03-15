import Foundation
import CoreML

final class NoiseContextInferenceEngine: @unchecked Sendable {
    private let modelProvider = CoreMLModelProvider()
    private var mlModel: MLModel?

    init() {
        mlModel = modelProvider.model(for: .noiseContextClassifier)
    }

    func classify(features: FeatureVector) -> [String] {
        if let mlModel, let result = classifyWithML(mlModel, features: features) {
            return result
        }
        return classifyWithRules(features: features)
    }

    private func classifyWithML(_ model: MLModel, features: FeatureVector) -> [String]? {
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

        guard let input = try? MLDictionaryFeatureProvider(dictionary: dict),
              let output = try? model.prediction(from: input),
              let label = output.featureValue(for: "noiseContext")?.stringValue else { return nil }

        return label == "quiet" ? [] : [label]
    }

    private func classifyWithRules(features: FeatureVector) -> [String] {
        var flags: [String] = []
        if features.spectralCentroid < 200 && features.rmsEnergy > 0.05 {
            flags.append("traffic_or_wind")
        }
        if features.spectralFlatness > 0.8 && features.rmsEnergy > 0.1 {
            flags.append("broadband_noise")
        }
        if features.zeroCrossingRate > 0.02 && features.zeroCrossingRate < 0.3 &&
           features.spectralCentroid > 300 && features.spectralCentroid < 3400 {
            flags.append("speech_or_tv")
        }
        if features.rmsEnergy > 0.5 { flags.append("loud_transient") }
        if features.spectralFlatness < 0.1 && features.rmsEnergy > 0.02 { flags.append("tonal_sound") }
        return flags
    }
}
