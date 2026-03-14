import Foundation
import Accelerate

final class AudioPreprocessor: Sendable {
    private let preEmphasisCoeff: Float = 0.97

    func process(frame: AudioFrame) -> ProcessedFrame {
        var samples = frame.samples
        guard !samples.isEmpty else {
            return ProcessedFrame(timestamp: frame.timestamp, samples: [], noiseLevel: -100, isVoiceActivity: false)
        }

        samples = removeDCOffset(samples)
        samples = applyPreEmphasis(samples)
        samples = normalize(samples)

        let rms = computeRMS(samples)
        let noiseLevel = rms > 0 ? 20.0 * log10(Double(rms)) : -100.0
        let isVoice = rms > 0.01

        return ProcessedFrame(timestamp: frame.timestamp, samples: samples, noiseLevel: noiseLevel, isVoiceActivity: isVoice)
    }

    private func removeDCOffset(_ samples: [Float]) -> [Float] {
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        var result = [Float](repeating: 0, count: samples.count)
        var negMean = -mean
        vDSP_vsadd(samples, 1, &negMean, &result, 1, vDSP_Length(samples.count))
        return result
    }

    private func applyPreEmphasis(_ samples: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: samples.count)
        result[0] = samples[0]
        for i in 1..<samples.count {
            result[i] = samples[i] - preEmphasisCoeff * samples[i - 1]
        }
        return result
    }

    private func normalize(_ samples: [Float]) -> [Float] {
        var maxVal: Float = 0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))
        guard maxVal > 0 else { return samples }
        var result = [Float](repeating: 0, count: samples.count)
        var scale = 1.0 / maxVal
        vDSP_vsmul(samples, 1, &scale, &result, 1, vDSP_Length(samples.count))
        return result
    }

    private func computeRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }
}
