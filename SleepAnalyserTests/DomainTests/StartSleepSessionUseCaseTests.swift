import XCTest
@testable import SleepAnalyser

final class StartSleepSessionUseCaseTests: XCTestCase {
    var sessionRepo: MockSessionRepository!
    var profileRepo: MockProfileRepository!
    var clock: MockClock!
    var sut: StartSleepSessionUseCase!

    override func setUp() {
        sessionRepo = MockSessionRepository()
        profileRepo = MockProfileRepository()
        clock = MockClock()
        sut = StartSleepSessionUseCase(sessionRepo: sessionRepo, profileRepo: profileRepo, clock: clock)
    }

    func test_execute_createsSessionWithRecordingState() async throws {
        let profile = UserProfile(name: "Test")
        try await profileRepo.createProfile(profile)

        let session = try await sut.execute(profileId: profile.id)
        XCTAssertEqual(session.state, .recording)
        XCTAssertEqual(session.profileId, profile.id)
    }

    func test_execute_throwsWhenProfileNotFound() async {
        do {
            _ = try await sut.execute(profileId: UUID())
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is SleepSessionError)
        }
    }

    func test_execute_persistsSession() async throws {
        let profile = UserProfile(name: "Test")
        try await profileRepo.createProfile(profile)

        let session = try await sut.execute(profileId: profile.id)
        let fetched = try await sessionRepo.getSession(id: session.id)
        XCTAssertNotNil(fetched)
    }
}
