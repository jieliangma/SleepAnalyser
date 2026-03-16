import Foundation
import Accelerate

final class AdaptiveBreathFilter: @unchecked Sendable {
    private var lowCutoff: Float = 200
    private var highCutoff: Float = 2000
    private let sampleRate: Float
    private var lastBPM: Double = 0
    private var adaptCount: Int = 0

    init(sampleRate: Float = 16000) {
        self.sampleRate = sampleRate
    }

    func adapt(detectedBPM: Double) {
        guard detectedBPM > 5 && detectedBPM < 35 else { return }
        adaptCount += 1
        if adaptCount < 3 { return }
        lastBPM = detectedBPM
        let breathFreq = Float(detectedBPM / 60.0)
        lowCutoff = max(100, 200 - breathFreq * 20)
        highCutoff = min(2500, 1500 + breathFreq * 50)
    }

    func filter(_ samples: [Float]) -> [Float] {
        guard samples.count >= 4 else { return samples }
        let n = samples.count
        let log2n = vDSP_Length(log2(Float(n)).rounded(.up))
        let fftN = Int(1 << log2n)

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return samples }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = [Float](repeating: 0, count: fftN)
        var imag = [Float](repeating: 0, count: fftN)
        for i in 0..<n { real[i] = samples[i] }

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        let freqResolution = sampleRate / Float(fftN)
        let lowBin = Int(lowCutoff / freqResolution)
        let highBin = Int(highCutoff / freqResolution)

        for i in 0..<fftN {
            if i < lowBin || i > highBin {
                real[i] = 0
                imag[i] = 0
            }
        }

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
            }
        }

        var scale = 1.0 / Float(fftN)
        var output = [Float](repeating: 0, count: n)
        vDSP_vsmul(Array(real.prefix(n)), 1, &scale, &output, 1, vDSP_Length(n))
        return output
    }
}
