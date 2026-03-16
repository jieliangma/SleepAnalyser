import Foundation
import Accelerate

final class AdaptiveBreathFilter: @unchecked Sendable {
    private var lowCutoff: Float = 200
    private var highCutoff: Float = 2000
    private let sampleRate: Float
    private var adaptCount: Int = 0
    private let rolloffHz: Float = 50.0

    private let fftSize: Int = 1024
    private let hopSize: Int = 512
    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length
    private let hann: [Float]

    init(sampleRate: Float = 16000) {
        self.sampleRate = sampleRate
        let n = vDSP_Length(log2(Float(1024)))
        self.log2n = n
        self.fftSetup = vDSP_create_fftsetup(n, FFTRadix(kFFTRadix2))
        self.hann = (0..<1024).map { 0.5 * (1.0 - cos(2.0 * .pi * Float($0) / Float(1023))) }
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
    }

    func adapt(detectedBPM: Double) {
        guard detectedBPM > 5 && detectedBPM < 35 else { return }
        adaptCount += 1
        if adaptCount < 3 { return }
        let breathFreq = Float(detectedBPM / 60.0)
        lowCutoff = max(100, 200 - breathFreq * 20)
        highCutoff = min(2500, 1500 + breathFreq * 50)
    }

    func filter(_ samples: [Float]) -> [Float] {
        guard samples.count >= fftSize, let setup = fftSetup else { return samples }

        let freqRes = sampleRate / Float(fftSize)
        let halfN = fftSize / 2

        var outputAccum = [Float](repeating: 0, count: samples.count + fftSize)
        var windowSum   = [Float](repeating: 0, count: samples.count + fftSize)

        var frameStart = 0
        while frameStart + fftSize <= samples.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(Array(samples[frameStart..<frameStart + fftSize]), 1, hann, 1, &windowed, 1, vDSP_Length(fftSize))

            var real = windowed
            var imag = [Float](repeating: 0, count: fftSize)

            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                }
            }

            for i in 0..<halfN {
                let freq = Float(i) * freqRes
                let g = bandpassGain(freq: freq)
                real[i] *= g
                imag[i] *= g
            }
            for i in halfN..<fftSize {
                let mirrorFreq = Float(fftSize - i) * freqRes
                let g = bandpassGain(freq: mirrorFreq)
                real[i] *= g
                imag[i] *= g
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

        var output = [Float](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            output[i] = windowSum[i] > 1e-10 ? outputAccum[i] / windowSum[i] : samples[i]
        }
        return output
    }

    private func bandpassGain(freq: Float) -> Float {
        if freq < lowCutoff - rolloffHz {
            return 0
        } else if freq < lowCutoff {
            let t = (freq - (lowCutoff - rolloffHz)) / rolloffHz
            return 0.5 * (1.0 - cos(.pi * t))
        } else if freq <= highCutoff {
            return 1.0
        } else if freq < highCutoff + rolloffHz {
            let t = (freq - highCutoff) / rolloffHz
            return 0.5 * (1.0 + cos(.pi * t))
        } else {
            return 0
        }
    }
}
