import Foundation

enum EventMapper {
    static func toDomain(_ sd: SDAudioEvent) -> AudioEvent {
        AudioEvent(
            id: sd.id, sessionId: sd.sessionId,
            eventType: EventType(rawValue: sd.eventTypeRawValue) ?? .disturbance,
            source: sd.sourceRawValue.flatMap { DisturbanceSource(rawValue: $0) },
            startAt: sd.startAt, endAt: sd.endAt,
            severity: sd.severity, confidence: sd.confidence,
            audioClipURL: sd.audioClipPath.flatMap { URL(fileURLWithPath: $0) },
            isConfirmed: sd.isConfirmed,
            userLabel: sd.userLabel
        )
    }

    static func toSD(_ domain: AudioEvent) -> SDAudioEvent {
        SDAudioEvent(
            id: domain.id, sessionId: domain.sessionId,
            eventTypeRawValue: domain.eventType.rawValue,
            sourceRawValue: domain.source?.rawValue,
            startAt: domain.startAt, endAt: domain.endAt,
            severity: domain.severity, confidence: domain.confidence,
            audioClipPath: domain.audioClipURL?.path,
            isConfirmed: domain.isConfirmed,
            userLabel: domain.userLabel
        )
    }
}
