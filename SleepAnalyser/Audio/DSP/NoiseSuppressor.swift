import Foundation
import Accelerate

final class NoiseSuppressor: @unchecked Sendable {
    private var noiseFloor: [Float]?
    private let overSubtractionFactor: Float
    private let floorFactor: Float = 0.01
    private let smoothingAlpha: Float = 0.98
    private let fftSize: Int
    private let hopSize: Int
    private var gainFactor: Float = 1.0
    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length

    init(fftSize: Int = 1024, overSubtractionFactor: Float = 2.0) {
        self.fftSize = fftSize
        self.hopSize = fftSize / 2
        self.overSubtractionFactor = overSubtractionFactor
        let n = vDSP_Length(log2(Float(fftSize)))
        self.log2n = n
        self.fftSetup = vDSP_create_fftsetup(n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
    }

    func loadRoomCalibration(noiseFloorSpectrum: Data?, baselineNoiseLevel: Double, micGainFactor: Double) {
        if let data = noiseFloorSpectrum {
            noiseFloor = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        gainFactor = Float(micGainFactor)
    }

    func suppress(_ samples: [Float]) -> [Float] {
        guard samples.count >= fftSize, let setup = fftSetup else { return samples }

        var input = samples
        if gainFactor != 1.0 {
            var g = gainFactor
            vDSP_vsmul(samples, 1, &g, &input, 1, vDSP_Length(samples.count))
        }

        let halfN = fftSize / 2
        var outputAccum = [Float](repeating: 0, count: input.count + fftSize)
        var windowSum  = [Float](repeating: 0, count: input.count + fftSize)

        let hann: [Float] = (0..<fftSize).map {
            0.5 * (1.0 - cos(2.0 * .pi * Float($0) / Float(fftSize - 1)))
        }

        var frameStart = 0
        while frameStart + fftSize <= input.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(Array(input[frameStart..<frameStart + fftSize]), 1, hann, 1, &windowed, 1, vDSP_Length(fftSize))

            var real = windowed
            var imag = [Float](repeating: 0, count: fftSize)

            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                }
            }

            var magnitude = [Float](repeating: 0, count: halfN)
            for i in 0..<halfN {
                magnitude[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
            }

            if noiseFloor == nil {
                noiseFloor = magnitude
            }

            if var floor = noiseFloor {
                let binCount = min(magnitude.count, floor.count)
                for i in 0..<binCount {
                    floor[i] = smoothingAlpha * floor[i] + (1 - smoothingAlpha) * min(magnitude[i], floor[i] * 3)
                }
                noiseFloor = floor

                var gain = [Float](repeating: 1, count: halfN)
                for i in 0..<halfN {
                    let floorVal = i < floor.count ? floor[i] : 0
                    let cleaned = max(magnitude[i] - overSubtractionFactor * floorVal,
                                      floorFactor * magnitude[i])
                    gain[i] = magnitude[i] > 1e-10 ? cleaned / magnitude[i] : 0
                }

                for i in 0..<halfN {
                    real[i] *= gain[i]
                    imag[i] *= gain[i]
                }
                let mirrorStart = halfN
                let mirrorCount = fftSize - halfN
                for i in 0..<mirrorCount {
                    let srcIdx = halfN - 1 - min(i, halfN - 1)
                    let g = srcIdx < gain.count ? gain[srcIdx] : 1.0
                    real[mirrorStart + i] *= g
                    imag[mirrorStart + i] *= g
                }
            }

            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
                }
            }

            var scale = 1.0 / Float(fftSize)
            var frame = [Float](repeating: 0, count: fftSize)
            vDSP_vsmul(real, 1, &scale, &frame, 1, vDSP_Length(fftSize))

            var windowedOut = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(frame, 1, hann, 1, &windowedOut, 1, vDSP_Length(fftSize))

            for i in 0..<fftSize {
                outputAccum[frameStart + i] += windowedOut[i]
                windowSum[frameStart + i]   += hann[i] * hann[i]
            }

            frameStart += hopSize
        }

        var output = [Float](repeating: 0, count: input.count)
        for i in 0..<input.count {
            output[i] = windowSum[i] > 1e-10 ? outputAccum[i] / windowSum[i] : input[i]
        }
        return output
    }

    func exportNoiseFloorSpectrum() -> Data? {
        guard let floor = noiseFloor else { return nil }
        return floor.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
