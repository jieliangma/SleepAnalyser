import Foundation

struct AudioEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    var eventType: EventType
    var source: DisturbanceSource?
    let startAt: Date
    var endAt: Date
    var severity: Double
    var confidence: Double
    var audioClipURL: URL?
    var isConfirmed: Bool
    var userLabel: String?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        eventType: EventType,
        source: DisturbanceSource? = nil,
        startAt: Date,
        endAt: Date,
        severity: Double = 0.5,
        confidence: Double = 0.5,
        audioClipURL: URL? = nil,
        isConfirmed: Bool = false,
        userLabel: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.eventType = eventType
        self.source = source
        self.startAt = startAt
        self.endAt = endAt
        self.severity = severity
        self.confidence = confidence
        self.audioClipURL = audioClipURL
        self.isConfirmed = isConfirmed
        self.userLabel = userLabel
    }

    var duration: TimeInterval {
        endAt.timeIntervalSince(startAt)
    }

    var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel(rawConfidence: confidence)
    }

    var hasAudioClip: Bool {
        audioClipURL != nil
    }
}
