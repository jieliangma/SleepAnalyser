import Foundation
import Accelerate

final class SpectralFeatureExtractor: Sendable {
    private let fftSize: Int
    private let numMelBands: Int
    private let numMFCC: Int
    private let sampleRate: Double

    init(fftSize: Int = 1024, numMelBands: Int = 40, numMFCC: Int = 13, sampleRate: Double = 16000) {
        self.fftSize = fftSize
        self.numMelBands = numMelBands
        self.numMFCC = numMFCC
        self.sampleRate = sampleRate
    }

    func extractFeatures(from frame: ProcessedFrame) -> FeatureVector {
        let samples = frame.samples
        let magnitude = computeFFTMagnitude(samples)
        let melEnergies = computeMelEnergies(magnitude)
        let mfcc = computeMFCC(melEnergies)

        let centroid = computeSpectralCentroid(magnitude)
        let rolloff = computeSpectralRolloff(magnitude)
        let flatness = computeSpectralFlatness(magnitude)
        let zcr = computeZeroCrossingRate(samples)
        let rms = computeRMS(samples)

        return FeatureVector(
            timestamp: frame.timestamp,
            mfccCoefficients: mfcc,
            spectralCentroid: centroid,
            spectralRolloff: rolloff,
            spectralFlatness: flatness,
            zeroCrossingRate: zcr,
            rmsEnergy: rms,
            breathingPeriodicity: 0,
            breathIntervalVariability: 0
        )
    }

    private func computeFFTMagnitude(_ samples: [Float]) -> [Float] {
        let n = min(samples.count, fftSize)
        guard n > 0 else { return [] }
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

        let halfN = fftN / 2
        var mag = [Float](repeating: 0, count: halfN)
        for i in 0..<halfN {
            mag[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }
        return mag
    }

    // Approximate mel filterbank energies
    private func computeMelEnergies(_ magnitude: [Float]) -> [Float] {
        guard !magnitude.isEmpty else { return [Float](repeating: 0, count: numMelBands) }
        let binsPerBand = max(1, magnitude.count / numMelBands)
        var energies = [Float](repeating: 0, count: numMelBands)
        for band in 0..<numMelBands {
            let start = band * binsPerBand
            let end = min(start + binsPerBand, magnitude.count)
            guard start < end else { continue }
            var sum: Float = 0
            for i in start..<end { sum += magnitude[i] * magnitude[i] }
            energies[band] = log(max(sum / Float(end - start), 1e-10))
        }
        return energies
    }

    // DCT-II on log mel energies to get MFCC
    private func computeMFCC(_ melEnergies: [Float]) -> [Float] {
        let n = melEnergies.count
        var mfcc = [Float](repeating: 0, count: numMFCC)
        for k in 0..<numMFCC {
            var sum: Float = 0
            for j in 0..<n {
                sum += melEnergies[j] * cos(Float.pi * Float(k) * (Float(j) + 0.5) / Float(n))
            }
            mfcc[k] = sum
        }
        return mfcc
    }

    private func computeSpectralCentroid(_ magnitude: [Float]) -> Float {
        var weightedSum: Float = 0
        var totalEnergy: Float = 0
        for (i, m) in magnitude.enumerated() {
            weightedSum += Float(i) * m
            totalEnergy += m
        }
        return totalEnergy > 0 ? weightedSum / totalEnergy : 0
    }

    private func computeSpectralRolloff(_ magnitude: [Float], threshold: Float = 0.85) -> Float {
        let total = magnitude.reduce(0, +)
        let target = total * threshold
        var cumSum: Float = 0
        for (i, m) in magnitude.enumerated() {
            cumSum += m
            if cumSum >= target { return Float(i) / Float(max(magnitude.count, 1)) }
        }
        return 1.0
    }

    private func computeSpectralFlatness(_ magnitude: [Float]) -> Float {
        guard !magnitude.isEmpty else { return 0 }
        let n = Float(magnitude.count)
        let logSum = magnitude.reduce(Float(0)) { $0 + log(max($1, 1e-10)) }
        let geometricMean = exp(logSum / n)
        let arithmeticMean = magnitude.reduce(0, +) / n
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }

    private func computeZeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings: Float = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i - 1] < 0) || (samples[i] < 0 && samples[i - 1] >= 0) {
                crossings += 1
            }
        }
        return crossings / Float(samples.count - 1)
    }

    private func computeRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }
}
