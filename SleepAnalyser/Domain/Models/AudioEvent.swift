import Foundation

struct AudioEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let eventType: EventType
    var source: DisturbanceSource?
    let startAt: Date
    var endAt: Date
    var severity: Double
    var confidence: Double

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        eventType: EventType,
        source: DisturbanceSource? = nil,
        startAt: Date,
        endAt: Date,
        severity: Double = 0.5,
        confidence: Double = 0.5
    ) {
        self.id = id
        self.sessionId = sessionId
        self.eventType = eventType
        self.source = source
        self.startAt = startAt
        self.endAt = endAt
        self.severity = severity
        self.confidence = confidence
    }

    var duration: TimeInterval {
        endAt.timeIntervalSince(startAt)
    }

    var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel(rawConfidence: confidence)
    }
}
