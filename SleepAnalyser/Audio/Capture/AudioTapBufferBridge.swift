import Foundation
import AVFoundation
import Accelerate

enum AudioTapBufferBridge {
    static func extractMonoSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }

        var mono = [Float](repeating: 0, count: frameLength)
        let scale = Float(1.0 / Double(channelCount))
        for ch in 0..<channelCount {
            vDSP_vsma(channelData[ch], 1, [scale], mono, 1, &mono, 1, vDSP_Length(frameLength))
        }
        return mono
    }

    static func resample(samples: [Float], fromRate: Double, toRate: Double) -> [Float] {
        guard fromRate != toRate, !samples.isEmpty else { return samples }
        let ratio = toRate / fromRate
        let outputLength = Int(Double(samples.count) * ratio)
        guard outputLength > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputLength)
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let frac = Float(srcIndex - Double(srcIndexInt))

            let s0 = samples[min(srcIndexInt, samples.count - 1)]
            let s1 = samples[min(srcIndexInt + 1, samples.count - 1)]
            output[i] = s0 + frac * (s1 - s0)
        }
        return output
    }
}
