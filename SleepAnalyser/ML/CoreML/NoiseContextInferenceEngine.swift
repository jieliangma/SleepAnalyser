import Foundation

final class NoiseContextInferenceEngine: Sendable {
    func classify(features: FeatureVector) -> [String] {
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

        if features.rmsEnergy > 0.5 {
            flags.append("loud_transient")
        }

        if features.spectralFlatness < 0.1 && features.rmsEnergy > 0.02 {
            flags.append("tonal_sound")
        }

        return flags
    }
}
