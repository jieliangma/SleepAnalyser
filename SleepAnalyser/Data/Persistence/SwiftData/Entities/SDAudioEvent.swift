import Foundation
import SwiftData

@Model
final class SDAudioEvent {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var eventTypeRawValue: String
    var sourceRawValue: String?
    var startAt: Date
    var endAt: Date
    var severity: Double
    var confidence: Double
    var audioClipPath: String?
    var isConfirmed: Bool
    var userLabel: String?

    var session: SDSleepSession?

    init(id: UUID = UUID(), sessionId: UUID, eventTypeRawValue: String, sourceRawValue: String? = nil,
         startAt: Date, endAt: Date, severity: Double = 0.5, confidence: Double = 0.5,
         audioClipPath: String? = nil, isConfirmed: Bool = false, userLabel: String? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.eventTypeRawValue = eventTypeRawValue
        self.sourceRawValue = sourceRawValue
        self.startAt = startAt
        self.endAt = endAt
        self.severity = severity
        self.confidence = confidence
        self.audioClipPath = audioClipPath
        self.isConfirmed = isConfirmed
        self.userLabel = userLabel
    }
}
