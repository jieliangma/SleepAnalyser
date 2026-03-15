import Foundation
import Accelerate

final class NoiseSuppressor: @unchecked Sendable {
    private var noiseFloor: [Float]?
    private let overSubtractionFactor: Float
    private let floorFactor: Float = 0.01
    private let smoothingAlpha: Float = 0.98
    private let fftSize: Int
    private var gainFactor: Float = 1.0

    init(fftSize: Int = 1024, overSubtractionFactor: Float = 2.0) {
        self.fftSize = fftSize
        self.overSubtractionFactor = overSubtractionFactor
    }

    func loadRoomCalibration(noiseFloorSpectrum: Data?, baselineNoiseLevel: Double, micGainFactor: Double) {
        if let data = noiseFloorSpectrum {
            noiseFloor = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        gainFactor = Float(micGainFactor)
    }

    func suppress(_ samples: [Float]) -> [Float] {
        guard samples.count >= fftSize else { return samples }

        var input = samples
        if gainFactor != 1.0 {
            var g = gainFactor
            vDSP_vsmul(samples, 1, &g, &input, 1, vDSP_Length(samples.count))
        }

        let magnitude = computeMagnitudeSpectrum(input)

        if noiseFloor == nil {
            noiseFloor = magnitude
            return input
        }

        guard var updatedFloor = noiseFloor else { return input }
        for i in 0..<min(magnitude.count, updatedFloor.count) {
            updatedFloor[i] = smoothingAlpha * updatedFloor[i] + (1 - smoothingAlpha) * min(magnitude[i], updatedFloor[i] * 3)
        }
        noiseFloor = updatedFloor

        var cleaned = [Float](repeating: 0, count: magnitude.count)
        for i in 0..<magnitude.count {
            let subtracted = magnitude[i] - overSubtractionFactor * updatedFloor[i]
            cleaned[i] = max(subtracted, floorFactor * magnitude[i])
        }

        let ratio = computeWienerGain(original: magnitude, cleaned: cleaned)
        var output = [Float](repeating: 0, count: input.count)
        for i in 0..<min(input.count, ratio.count) {
            output[i] = input[i] * ratio[min(i, ratio.count - 1)]
        }
        for i in ratio.count..<input.count {
            output[i] = input[i] * (ratio.last ?? 1.0)
        }
        return output
    }

    private func computeMagnitudeSpectrum(_ samples: [Float]) -> [Float] {
        let n = min(samples.count, fftSize)
        let log2n = vDSP_Length(log2(Float(n)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = [Float](samples.prefix(n))
        var imag = [Float](repeating: 0, count: n)
        let halfN = n / 2

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        var magnitude = [Float](repeating: 0, count: halfN)
        for i in 0..<halfN {
            magnitude[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }
        return magnitude
    }

    private func computeWienerGain(original: [Float], cleaned: [Float]) -> [Float] {
        var gain = [Float](repeating: 0, count: original.count)
        for i in 0..<original.count {
            gain[i] = original[i] > 0 ? cleaned[i] / original[i] : 0
        }
        return gain
    }

    func exportNoiseFloorSpectrum() -> Data? {
        guard let floor = noiseFloor else { return nil }
        return floor.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
