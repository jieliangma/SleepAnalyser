import Foundation
import Accelerate

final class DisturbanceDetector: Sendable {
    private let transientThreshold: Float = 0.3
    private let sustainedThreshold: Float = 0.15

    func detect(samples: [Float], sampleRate: Double, sessionId: UUID, timestamp: Date, baselineRMS: Float) -> AudioEvent? {
        guard !samples.isEmpty else { return nil }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        let ratio = baselineRMS > 0 ? rms / baselineRMS : 0

        if ratio > 5.0 {
            let source = classifySource(samples: samples, sampleRate: sampleRate)
            return AudioEvent(
                sessionId: sessionId,
                eventType: .disturbance,
                source: source,
                startAt: timestamp,
                endAt: timestamp.addingTimeInterval(Double(samples.count) / sampleRate),
                severity: min(1.0, Double(ratio / 10.0)),
                confidence: 0.7
            )
        }

        if ratio > 2.0 {
            let source = classifySource(samples: samples, sampleRate: sampleRate)
            return AudioEvent(
                sessionId: sessionId,
                eventType: .disturbance,
                source: source,
                startAt: timestamp,
                endAt: timestamp.addingTimeInterval(Double(samples.count) / sampleRate),
                severity: min(0.5, Double(ratio / 5.0)),
                confidence: 0.5
            )
        }

        return nil
    }

    private func classifySource(samples: [Float], sampleRate: Double) -> DisturbanceSource {
        let n = samples.count
        guard n > 0 else { return .unknown }

        var lowEnergy: Float = 0
        var highEnergy: Float = 0
        let midPoint = n / 4

        if midPoint > 0 {
            vDSP_rmsqv(Array(samples.prefix(midPoint)), 1, &lowEnergy, vDSP_Length(midPoint))
        }
        let remaining = Array(samples.suffix(from: midPoint))
        if !remaining.isEmpty {
            vDSP_rmsqv(remaining, 1, &highEnergy, vDSP_Length(remaining.count))
        }

        let crestFactor = computeCrestFactor(samples)

        if crestFactor > 10.0 { return .alarm }
        if lowEnergy > highEnergy * 2.0 { return .traffic }
        if highEnergy > lowEnergy * 1.5 { return .partner }

        return .unknown
    }

    private func computeCrestFactor(_ samples: [Float]) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms > 0 ? peak / rms : 0
    }
}
