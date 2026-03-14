import Foundation
import Accelerate

final class SnoreDetector: Sendable {
    private let snoreLowFreq: Float = 100
    private let snoreHighFreq: Float = 800
    private let minDuration: TimeInterval = 0.5
    private let cooldownPeriod: TimeInterval = 2.0
    private let energyThreshold: Float = 0.05

    func detect(samples: [Float], sampleRate: Double, sessionId: UUID, timestamp: Date, lastEventEnd: Date?) -> AudioEvent? {
        guard samples.count > 100 else { return nil }

        if let lastEnd = lastEventEnd, timestamp.timeIntervalSince(lastEnd) < cooldownPeriod {
            return nil
        }

        let freqResolution = Float(sampleRate) / Float(samples.count)
        let lowBin = Int(snoreLowFreq / freqResolution)
        let highBin = Int(snoreHighFreq / freqResolution)
        let magnitude = computeMagnitude(samples)
        guard lowBin < highBin, highBin < magnitude.count else { return nil }

        let snoreBandEnergy = magnitude[lowBin..<highBin].reduce(0, +) / Float(highBin - lowBin)
        let totalEnergy = magnitude.reduce(0, +) / Float(max(magnitude.count, 1))
        let ratio = totalEnergy > 0 ? snoreBandEnergy / totalEnergy : 0

        guard ratio > 0.3, snoreBandEnergy > energyThreshold else { return nil }

        let harmonicScore = detectHarmonics(magnitude: Array(magnitude), lowBin: lowBin, highBin: highBin)
        guard harmonicScore > 0.2 else { return nil }

        let intensity = min(1.0, Double(ratio * harmonicScore * 2))

        return AudioEvent(
            sessionId: sessionId,
            eventType: .snore,
            startAt: timestamp,
            endAt: timestamp.addingTimeInterval(minDuration),
            severity: intensity,
            confidence: Double(harmonicScore)
        )
    }

    private func detectHarmonics(magnitude: [Float], lowBin: Int, highBin: Int) -> Float {
        guard highBin > lowBin else { return 0 }
        let range = magnitude[lowBin..<highBin]
        guard let peakVal = range.max(), peakVal > 0 else { return 0 }
        let peakIdx = range.firstIndex(of: peakVal).map { $0 - lowBin } ?? 0

        var harmonicEnergy: Float = 0
        for h in 2...4 {
            let harmonicBin = lowBin + peakIdx * h
            if harmonicBin < magnitude.count {
                harmonicEnergy += magnitude[harmonicBin]
            }
        }
        return min(1.0, harmonicEnergy / (peakVal * 3))
    }

    private func computeMagnitude(_ samples: [Float]) -> [Float] {
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
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        return (0..<fftN/2).map { sqrt(real[$0]*real[$0] + imag[$0]*imag[$0]) }
    }
}
