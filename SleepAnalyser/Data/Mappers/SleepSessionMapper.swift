import Foundation

enum SleepSessionMapper {
    static func toDomain(_ sd: SDSleepSession) -> SleepSession {
        SleepSession(
            id: sd.id, profileId: sd.profileId, startAt: sd.startAt, endAt: sd.endAt,
            state: SessionState(rawValue: sd.stateRawValue) ?? .idle,
            timezone: sd.timezone,
            epochs: sd.epochs.map { EpochMapper.toDomain($0) },
            events: sd.events.map { EventMapper.toDomain($0) }
        )
    }

    static func toSD(_ domain: SleepSession) -> SDSleepSession {
        SDSleepSession(
            id: domain.id, profileId: domain.profileId, startAt: domain.startAt,
            endAt: domain.endAt, stateRawValue: domain.state.rawValue, timezone: domain.timezone
        )
    }

    static func update(_ sd: SDSleepSession, from domain: SleepSession) {
        sd.endAt = domain.endAt
        sd.stateRawValue = domain.state.rawValue
    }
}

enum EpochMapper {
    static func toDomain(_ sd: SDSleepEpoch) -> SleepEpoch {
        let flags = (try? JSONDecoder().decode([String].self, from: Data(sd.contextFlagsJSON.utf8))) ?? []
        return SleepEpoch(
            id: sd.id, sessionId: sd.sessionId, timestamp: sd.timestamp,
            predictedStage: SleepStage(rawValue: sd.stageRawValue) ?? .unknown,
            confidence: sd.confidence, respirationRate: sd.respirationRate,
            snoreIntensity: sd.snoreIntensity, contextFlags: flags
        )
    }

    static func toSD(_ domain: SleepEpoch) -> SDSleepEpoch {
        let flagsJSON = (try? String(data: JSONEncoder().encode(domain.contextFlags), encoding: .utf8)) ?? "[]"
        return SDSleepEpoch(
            id: domain.id, sessionId: domain.sessionId, timestamp: domain.timestamp,
            stageRawValue: domain.predictedStage.rawValue, confidence: domain.confidence,
            respirationRate: domain.respirationRate, snoreIntensity: domain.snoreIntensity,
            contextFlagsJSON: flagsJSON
        )
    }
}
