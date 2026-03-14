import Foundation

final class StartSleepSessionUseCase: Sendable {
    private let sessionRepo: any SessionRepositoryProtocol
    private let profileRepo: any ProfileRepositoryProtocol
    private let clock: any ClockProtocol

    init(sessionRepo: any SessionRepositoryProtocol,
         profileRepo: any ProfileRepositoryProtocol,
         clock: any ClockProtocol = SystemClock()) {
        self.sessionRepo = sessionRepo
        self.profileRepo = profileRepo
        self.clock = clock
    }

    func execute(profileId: UUID) async throws -> SleepSession {
        guard let profile = try await profileRepo.getProfile(id: profileId) else {
            throw SleepSessionError.profileNotFound
        }

        let session = SleepSession(
            profileId: profile.id,
            startAt: clock.now(),
            state: .recording
        )
        try await sessionRepo.createSession(session)
        return session
    }
}

enum SleepSessionError: Error, LocalizedError {
    case profileNotFound
    case sessionNotFound
    case invalidStateTransition
    case sessionAlreadyStopped

    var errorDescription: String? {
        switch self {
        case .profileNotFound: return "User profile not found"
        case .sessionNotFound: return "Sleep session not found"
        case .invalidStateTransition: return "Invalid session state transition"
        case .sessionAlreadyStopped: return "Session has already been stopped"
        }
    }
}
