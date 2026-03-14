import Foundation

final class StopSleepSessionUseCase: Sendable {
    private let sessionRepo: any SessionRepositoryProtocol
    private let clock: any ClockProtocol

    init(sessionRepo: any SessionRepositoryProtocol,
         clock: any ClockProtocol = SystemClock()) {
        self.sessionRepo = sessionRepo
        self.clock = clock
    }

    func execute(sessionId: UUID) async throws -> SleepSession {
        guard var session = try await sessionRepo.getSession(id: sessionId) else {
            throw SleepSessionError.sessionNotFound
        }

        guard session.state.canTransition(to: .stopped) else {
            throw SleepSessionError.sessionAlreadyStopped
        }

        session.state = .stopped
        session.endAt = clock.now()
        try await sessionRepo.updateSession(session)
        return session
    }
}
