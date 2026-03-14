import Foundation
@testable import SleepAnalyser

enum TestAudioFixtures {
    static func sineWave(frequency: Float, duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return (0..<sampleCount).map { i in
            sin(2.0 * Float.pi * frequency * Float(i) / Float(sampleRate))
        }
    }

    static func whiteNoise(duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return (0..<sampleCount).map { _ in Float.random(in: -1...1) }
    }

    // Amplitude-modulated noise simulating periodic breathing
    static func breathingPattern(bpm: Double, duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        let breathFreq = bpm / 60.0
        return (0..<sampleCount).map { i in
            let t = Double(i) / sampleRate
            let envelope = Float(0.5 + 0.5 * sin(2.0 * Double.pi * breathFreq * t))
            return envelope * Float.random(in: -0.3...0.3)
        }
    }

    static func snorePattern(duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        let fundamental: Float = 150
        return (0..<sampleCount).map { i in
            let t = Float(i) / Float(sampleRate)
            let h1 = 0.5 * sin(2.0 * Float.pi * fundamental * t)
            let h2 = 0.3 * sin(2.0 * Float.pi * fundamental * 2 * t)
            let h3 = 0.2 * sin(2.0 * Float.pi * fundamental * 3 * t)
            return h1 + h2 + h3
        }
    }

    static func silence(duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        [Float](repeating: 0, count: Int(duration * sampleRate))
    }

    static func impulse(at position: Double = 0.5, duration: TimeInterval, sampleRate: Double = 16000) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: sampleCount)
        let impulseIndex = Int(position * Double(sampleCount))
        if impulseIndex < sampleCount {
            let spread = 10
            for i in Swift.max(0, impulseIndex - spread)..<Swift.min(sampleCount, impulseIndex + spread) {
                samples[i] = 0.9 * exp(-Float(abs(i - impulseIndex)) / Float(spread))
            }
        }
        return samples
    }

    static func makeAudioFrame(samples: [Float], sampleRate: Double = 16000) -> AudioFrame {
        AudioFrame(timestamp: Date(), samples: samples, sampleRate: sampleRate, channelCount: 1)
    }
}
