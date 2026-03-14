import Foundation
import Accelerate

final class DisturbanceDetector: @unchecked Sendable {
    private let sampleRate: Double = 16000
    private var recentSpectra: [[Float]] = []
    private let spectraHistorySize = 10

    struct FrequencyBands {
        let subBass: Float      // 20-80 Hz: wind rumble, heavy trucks
        let bass: Float         // 80-250 Hz: car engines, HVAC, motorcycles
        let lowMid: Float       // 250-500 Hz: motorcycle exhaust harmonics
        let mid: Float          // 500-2000 Hz: horns, speech range
        let highMid: Float      // 2000-4000 Hz: tire noise, speech sibilance
        let high: Float         // 4000-8000 Hz: brakes, sharp transients
    }

    func detect(samples: [Float], sampleRate: Double, sessionId: UUID, timestamp: Date, baselineRMS: Float) -> AudioEvent? {
        guard samples.count >= 512 else { return nil }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        let ratio = baselineRMS > 0 ? rms / baselineRMS : 0
        guard ratio > 1.5 else { return nil }

        let magnitude = computeMagnitude(samples, sr: sampleRate)
        let bands = computeBands(magnitude, sr: sampleRate, n: samples.count)
        recentSpectra.append(magnitude)
        if recentSpectra.count > spectraHistorySize { recentSpectra.removeFirst() }

        let source = classifyBySpectrum(bands: bands, crestFactor: computeCrestFactor(samples))
        let severity = computeSeverity(ratio: ratio, source: source)

        guard severity > 0.15 else { return nil }

        return AudioEvent(
            sessionId: sessionId,
            eventType: .disturbance,
            source: source,
            startAt: timestamp,
            endAt: timestamp.addingTimeInterval(Double(samples.count) / sampleRate),
            severity: severity,
            confidence: min(1.0, Double(ratio) / 5.0)
        )
    }

    private func classifyBySpectrum(bands: FrequencyBands, crestFactor: Float) -> DisturbanceSource {
        let totalLow = bands.subBass + bands.bass
        let totalMid = bands.lowMid + bands.mid
        let totalHigh = bands.highMid + bands.high
        let total = totalLow + totalMid + totalHigh
        guard total > 0 else { return .unknown }

        let lowRatio = totalLow / total
        let midRatio = totalMid / total

        // Wind: dominated by sub-bass, broadband, no harmonic structure
        if bands.subBass > bands.bass * 1.5 && lowRatio > 0.6 && crestFactor < 4.0 {
            return .rain // wind/rain share similar spectral profile
        }

        // Heavy traffic (car/truck): strong bass 80-250Hz + low-mid, sustained
        if bands.bass > bands.mid * 2.0 && lowRatio > 0.5 {
            return .traffic
        }

        // Motorcycle: strong bass + prominent low-mid harmonics (250-500Hz exhaust), higher crest
        if bands.lowMid > bands.mid && bands.bass > bands.highMid * 1.5 && crestFactor > 3.0 {
            return .traffic
        }

        // Horn/alarm: sharp transient, mid-high dominant
        if crestFactor > 8.0 && midRatio > 0.4 {
            return .alarm
        }

        // HVAC: steady-state, broadband with bass emphasis, very low crest factor
        if lowRatio > 0.4 && crestFactor < 3.0 && isStationary() {
            return .hvac
        }

        // Speech/TV: mid-range dominant 500-4000Hz
        if midRatio > 0.45 && bands.mid > totalLow {
            return .partner
        }

        if crestFactor > 6.0 { return .alarm }

        return .unknown
    }

    private func isStationary() -> Bool {
        guard recentSpectra.count >= 3 else { return false }
        let last = recentSpectra.suffix(3)
        let means = last.map { $0.reduce(0, +) / Float(max($0.count, 1)) }
        guard let maxM = means.max(), let minM = means.min(), maxM > 0 else { return false }
        return (maxM - minM) / maxM < 0.3
    }

    private func computeSeverity(ratio: Float, source: DisturbanceSource) -> Double {
        let base = min(1.0, Double(ratio) / 8.0)
        switch source {
        case .traffic: return min(1.0, base * 1.2)
        case .alarm: return min(1.0, base * 1.5)
        case .hvac: return base * 0.5
        case .rain: return base * 0.3
        default: return base
        }
    }

    private func computeBands(_ magnitude: [Float], sr: Double, n: Int) -> FrequencyBands {
        let binWidth = Float(sr) / Float(n)
        func bandEnergy(low: Float, high: Float) -> Float {
            let lo = max(0, Int(low / binWidth))
            let hi = min(magnitude.count - 1, Int(high / binWidth))
            guard lo <= hi else { return 0 }
            return magnitude[lo...hi].reduce(0, +) / Float(hi - lo + 1)
        }
        return FrequencyBands(
            subBass: bandEnergy(low: 20, high: 80),
            bass: bandEnergy(low: 80, high: 250),
            lowMid: bandEnergy(low: 250, high: 500),
            mid: bandEnergy(low: 500, high: 2000),
            highMid: bandEnergy(low: 2000, high: 4000),
            high: bandEnergy(low: 4000, high: 8000)
        )
    }

    private func computeMagnitude(_ samples: [Float], sr: Double) -> [Float] {
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

    private func computeCrestFactor(_ samples: [Float]) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms > 0 ? peak / rms : 0
    }
}
