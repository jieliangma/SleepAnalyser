import Foundation
import Accelerate

final class SpectralFeatureExtractor: Sendable {
    private let fftSize: Int
    private let numMelBands: Int
    private let numMFCC: Int
    private let sampleRate: Double
    private let melFilterbank: [[Float]]

    init(fftSize: Int = 1024, numMelBands: Int = 40, numMFCC: Int = 13, sampleRate: Double = 16000) {
        self.fftSize = fftSize
        self.numMelBands = numMelBands
        self.numMFCC = numMFCC
        self.sampleRate = sampleRate
        self.melFilterbank = SpectralFeatureExtractor.buildMelFilterbank(
            fftSize: fftSize, numBands: numMelBands,
            sampleRate: sampleRate, fMin: 80.0, fMax: sampleRate / 2
        )
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

    private static func hzToMel(_ hz: Double) -> Double {
        return 2595.0 * log10(1.0 + hz / 700.0)
    }

    private static func melToHz(_ mel: Double) -> Double {
        return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
    }

    private static func buildMelFilterbank(
        fftSize: Int, numBands: Int, sampleRate: Double, fMin: Double, fMax: Double
    ) -> [[Float]] {
        let numBins = fftSize / 2
        let freqResolution = sampleRate / Double(fftSize)

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)
        var melPoints = [Double](repeating: 0, count: numBands + 2)
        for i in 0..<(numBands + 2) {
            melPoints[i] = melMin + Double(i) * (melMax - melMin) / Double(numBands + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { Int(($0 / freqResolution).rounded()) }

        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: numBins), count: numBands)
        for m in 0..<numBands {
            let left   = binPoints[m]
            let center = binPoints[m + 1]
            let right  = binPoints[m + 2]
            for k in 0..<numBins {
                if k > left && k < center {
                    let denom = center - left
                    filterbank[m][k] = denom > 0 ? Float(k - left) / Float(denom) : 0
                } else if k == center {
                    filterbank[m][k] = 1.0
                } else if k > center && k < right {
                    let denom = right - center
                    filterbank[m][k] = denom > 0 ? Float(right - k) / Float(denom) : 0
                }
            }
        }
        return filterbank
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

    private func computeMelEnergies(_ magnitude: [Float]) -> [Float] {
        guard !magnitude.isEmpty else { return [Float](repeating: 0, count: numMelBands) }
        let numBins = min(magnitude.count, fftSize / 2)
        var energies = [Float](repeating: 0, count: numMelBands)
        for m in 0..<numMelBands {
            var energy: Float = 0
            let filter = melFilterbank[m]
            for k in 0..<numBins {
                energy += filter[k] * magnitude[k] * magnitude[k]
            }
            energies[m] = log(max(energy, 1e-10))
        }
        return energies
    }

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
