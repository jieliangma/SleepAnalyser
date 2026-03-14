import Foundation

protocol SessionRepositoryProtocol: Sendable {
    func createSession(_ session: SleepSession) async throws
    func getSession(id: UUID) async throws -> SleepSession?
    func updateSession(_ session: SleepSession) async throws
    func deleteSession(id: UUID) async throws
    func getSessions(from: Date, to: Date) async throws -> [SleepSession]
    func getLatestSession(profileId: UUID) async throws -> SleepSession?

    func addEpoch(_ epoch: SleepEpoch, toSession sessionId: UUID) async throws
    func getEpochs(forSession sessionId: UUID) async throws -> [SleepEpoch]

    func addEvent(_ event: AudioEvent, toSession sessionId: UUID) async throws
    func getEvents(forSession sessionId: UUID) async throws -> [AudioEvent]
}
