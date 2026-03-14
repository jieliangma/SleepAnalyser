import Foundation
import Accelerate

final class AGCNormalizer: @unchecked Sendable {
    private var currentGain: Float = 1.0
    let targetRMS: Float
    let attackTime: Float
    let releaseTime: Float
    let maxGain: Float
    let minGain: Float

    init(targetRMS: Float = 0.1, attackTime: Float = 0.01, releaseTime: Float = 0.1, maxGain: Float = 10.0, minGain: Float = 0.1) {
        self.targetRMS = targetRMS
        self.attackTime = attackTime
        self.releaseTime = releaseTime
        self.maxGain = maxGain
        self.minGain = minGain
    }

    func normalize(_ samples: [Float], sampleRate: Double) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        guard rms > 1e-10 else { return samples }

        let desiredGain = min(maxGain, max(minGain, targetRMS / rms))
        let frameDuration = Float(samples.count) / Float(sampleRate)
        let alpha = desiredGain > currentGain
            ? 1.0 - exp(-frameDuration / attackTime)
            : 1.0 - exp(-frameDuration / releaseTime)

        currentGain = currentGain + alpha * (desiredGain - currentGain)

        var output = [Float](repeating: 0, count: samples.count)
        var gain = currentGain
        vDSP_vsmul(samples, 1, &gain, &output, 1, vDSP_Length(samples.count))

        var peakLimit: Float = 1.0
        vDSP_vclip(output, 1, [Float(-peakLimit)], &peakLimit, &output, 1, vDSP_Length(output.count))
        return output
    }
}
