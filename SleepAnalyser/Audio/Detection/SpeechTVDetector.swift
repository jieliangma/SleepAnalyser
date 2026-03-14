import Foundation
import Accelerate

final class SpeechTVDetector: Sendable {
    private let speechLowFreq: Float = 300
    private let speechHighFreq: Float = 3400
    private let confidenceThreshold: Float = 0.4

    func detect(samples: [Float], sampleRate: Double, sessionId: UUID, timestamp: Date) -> AudioEvent? {
        guard samples.count > 100 else { return nil }

        let magnitude = computeMagnitude(samples, sampleRate: sampleRate)
        let freqRes = Float(sampleRate) / Float(samples.count)
        let lowBin = Int(speechLowFreq / freqRes)
        let highBin = Int(speechHighFreq / freqRes)
        guard lowBin < highBin, highBin < magnitude.count else { return nil }

        let speechEnergy = magnitude[lowBin..<highBin].reduce(0, +)
        let totalEnergy = magnitude.reduce(0, +)
        let ratio = totalEnergy > 0 ? speechEnergy / totalEnergy : 0

        let zcr = computeZCR(samples)
        let isSpeechLike = ratio > 0.4 && zcr > 0.02 && zcr < 0.3

        guard isSpeechLike else { return nil }

        return AudioEvent(
            sessionId: sessionId,
            eventType: .speech,
            source: .tv,
            startAt: timestamp,
            endAt: timestamp.addingTimeInterval(Double(samples.count) / sampleRate),
            severity: 0.4,
            confidence: Double(ratio)
        )
    }

    private func computeZCR(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings: Float = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) { crossings += 1 }
        }
        return crossings / Float(samples.count - 1)
    }

    private func computeMagnitude(_ samples: [Float], sampleRate: Double) -> [Float] {
        let n = samples.count
        let log2n = vDSP_Length(log2(Float(max(n, 2))).rounded(.up))
        let fftN = Int(1 << log2n)
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }

        var real = [Float](repeating: 0, count: fftN)
        var imag = [Float](repeating: 0, count: fftN)
        for i in 0..<min(n, fftN) { real[i] = samples[i] }

        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var s = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                vDSP_fft_zip(setup, &s, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        return (0..<fftN/2).map { sqrt(real[$0]*real[$0] + imag[$0]*imag[$0]) }
    }
}
