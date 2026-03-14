import Foundation
@testable import SleepAnalyser

final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    var sessions: [UUID: SleepSession] = [:]
    var epochs: [UUID: [SleepEpoch]] = [:]
    var events: [UUID: [AudioEvent]] = [:]

    func createSession(_ session: SleepSession) async throws {
        sessions[session.id] = session
    }

    func getSession(id: UUID) async throws -> SleepSession? {
        sessions[id]
    }

    func updateSession(_ session: SleepSession) async throws {
        sessions[session.id] = session
    }

    func deleteSession(id: UUID) async throws {
        sessions.removeValue(forKey: id)
        epochs.removeValue(forKey: id)
        events.removeValue(forKey: id)
    }

    func getSessions(from: Date, to: Date) async throws -> [SleepSession] {
        sessions.values.filter { $0.startAt >= from && $0.startAt <= to }
    }

    func getLatestSession(profileId: UUID) async throws -> SleepSession? {
        sessions.values.filter { $0.profileId == profileId }.sorted { $0.startAt > $1.startAt }.first
    }

    func addEpoch(_ epoch: SleepEpoch, toSession sessionId: UUID) async throws {
        epochs[sessionId, default: []].append(epoch)
    }

    func getEpochs(forSession sessionId: UUID) async throws -> [SleepEpoch] {
        epochs[sessionId] ?? []
    }

    func addEvent(_ event: AudioEvent, toSession sessionId: UUID) async throws {
        events[sessionId, default: []].append(event)
    }

    func getEvents(forSession sessionId: UUID) async throws -> [AudioEvent] {
        events[sessionId] ?? []
    }
}
