import Foundation
import Accelerate

final class BreathingRhythmEstimator: Sendable {
    private let sampleRate: Double
    private let minBPM: Double = 6.0
    private let maxBPM: Double = 30.0

    init(sampleRate: Double = 16000) {
        self.sampleRate = sampleRate
    }

    func estimate(from samples: [Float]) -> BreathingSample {
        guard samples.count > 100 else {
            return BreathingSample(breathsPerMinute: 0, regularity: 0, amplitude: 0)
        }

        let envelope = computeRMSEnvelope(samples, windowSize: Int(sampleRate * 0.1))
        let autocorr = computeAutocorrelation(envelope)

        let envelopeRate = sampleRate / Double(max(Int(sampleRate * 0.1), 1))
        let minLag = Int(60.0 / maxBPM * envelopeRate)
        let maxLag = Int(60.0 / minBPM * envelopeRate)

        guard minLag < maxLag, maxLag < autocorr.count else {
            return BreathingSample(breathsPerMinute: 0, regularity: 0, amplitude: 0)
        }

        var peakLag = minLag
        var peakVal: Float = -Float.infinity
        for lag in minLag..<min(maxLag, autocorr.count) {
            if autocorr[lag] > peakVal {
                peakVal = autocorr[lag]
                peakLag = lag
            }
        }

        let midLag = (minLag + maxLag) / 2
        let noiseRegion = Array(autocorr[midLag..<min(maxLag, autocorr.count)])
        let noiseFloor: Float = noiseRegion.isEmpty ? 0 : noiseRegion.reduce(0, +) / Float(noiseRegion.count)
        let prominence = peakVal > 1e-10 ? (peakVal - noiseFloor) / peakVal : 0
        let isValid = prominence > 0.3 && peakVal > 0.15

        let bpm = peakLag > 0 ? 60.0 * envelopeRate / Double(peakLag) : 0
        let regularity = Double(max(0, min(1, peakVal)))
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        return BreathingSample(
            breathsPerMinute: isValid ? min(maxBPM, max(minBPM, bpm)) : 0,
            regularity: isValid ? regularity : 0,
            amplitude: Double(rms),
            isValid: isValid
        )
    }

    private func computeRMSEnvelope(_ samples: [Float], windowSize: Int) -> [Float] {
        let ws = max(windowSize, 1)
        let outputCount = samples.count / ws
        guard outputCount > 0 else { return [] }
        var envelope = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let start = i * ws
            let end = min(start + ws, samples.count)
            var rms: Float = 0
            let slice = Array(samples[start..<end])
            vDSP_rmsqv(slice, 1, &rms, vDSP_Length(slice.count))
            envelope[i] = rms
        }
        return envelope
    }

    private func computeAutocorrelation(_ signal: [Float]) -> [Float] {
        let n = signal.count
        guard n > 1 else { return [] }
        var result = [Float](repeating: 0, count: n)
        var energy: Float = 0
        vDSP_dotpr(signal, 1, signal, 1, &energy, vDSP_Length(n))
        guard energy > 0 else { return result }

        for lag in 0..<n {
            var sum: Float = 0
            let len = n - lag
            vDSP_dotpr(signal, 1, Array(signal[lag...]), 1, &sum, vDSP_Length(len))
            result[lag] = sum / energy
        }
        return result
    }
}
