import XCTest
@testable import SleepAnalyser

final class StopSleepSessionUseCaseTests: XCTestCase {
    var sessionRepo: MockSessionRepository!
    var clock: MockClock!
    var sut: StopSleepSessionUseCase!

    override func setUp() {
        sessionRepo = MockSessionRepository()
        clock = MockClock()
        sut = StopSleepSessionUseCase(sessionRepo: sessionRepo, clock: clock)
    }

    func test_execute_transitionsToStopped() async throws {
        let session = SleepSession(profileId: UUID(), state: .recording)
        try await sessionRepo.createSession(session)

        let stopped = try await sut.execute(sessionId: session.id)
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertNotNil(stopped.endAt)
    }

    func test_execute_throwsForAlreadyStopped() async {
        let session = SleepSession(profileId: UUID(), state: .stopped)
        try! await sessionRepo.createSession(session)

        do {
            _ = try await sut.execute(sessionId: session.id)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is SleepSessionError)
        }
    }

    func test_execute_throwsForMissingSession() async {
        do {
            _ = try await sut.execute(sessionId: UUID())
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is SleepSessionError)
        }
    }
}
