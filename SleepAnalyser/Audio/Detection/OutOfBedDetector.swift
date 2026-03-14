import Foundation
import Accelerate

final class OutOfBedDetector: @unchecked Sendable {
    enum BedState: Sendable {
        case sleeping
        case possibleAwake
        case outOfBed
        case returnedToBed
    }

    private(set) var state: BedState = .sleeping
    private var silenceStartTime: Date?
    private let silenceThreshold: Float = 0.005
    private let silenceTimeout: TimeInterval = 60
    private let returnThreshold: TimeInterval = 10

    func update(samples: [Float], sessionId: UUID, timestamp: Date) -> AudioEvent? {
        var rms: Float = 0
        if !samples.isEmpty {
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        }
        let isSilent = rms < silenceThreshold

        switch state {
        case .sleeping:
            if isSilent {
                if silenceStartTime == nil { silenceStartTime = timestamp }
                if let start = silenceStartTime, timestamp.timeIntervalSince(start) > silenceTimeout {
                    state = .possibleAwake
                }
            } else {
                silenceStartTime = nil
            }
            return nil

        case .possibleAwake:
            if !isSilent {
                state = .outOfBed
                silenceStartTime = nil
                return AudioEvent(
                    sessionId: sessionId, eventType: .outOfBed,
                    startAt: timestamp, endAt: timestamp,
                    severity: 0.6, confidence: 0.6
                )
            }
            return nil

        case .outOfBed:
            if !isSilent && rms > silenceThreshold * 3 {
                state = .returnedToBed
                let event = AudioEvent(
                    sessionId: sessionId, eventType: .returnedToBed,
                    startAt: timestamp, endAt: timestamp,
                    severity: 0.1, confidence: 0.5
                )
                state = .sleeping
                silenceStartTime = nil
                return event
            }
            return nil

        case .returnedToBed:
            state = .sleeping
            silenceStartTime = nil
            return nil
        }
    }

    func reset() {
        state = .sleeping
        silenceStartTime = nil
    }
}
