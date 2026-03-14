import XCTest
@testable import SleepAnalyser

final class SleepSessionTests: XCTestCase {
    func test_sleepDuration_countsOnlyAsleepEpochs() {
        let sessionId = UUID()
        let session = SleepSession(
            profileId: UUID(), startAt: Date(), state: .recording,
            epochs: [
                SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .awake),
                SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .n2),
                SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .n3),
                SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .rem),
            ]
        )
        XCTAssertEqual(session.sleepDuration, 90.0, accuracy: 0.01)
    }

    func test_efficiency_ratioOfSleepToTotal() {
        let start = Date()
        let end = start.addingTimeInterval(28800)
        let sessionId = UUID()
        var epochs = [SleepEpoch]()
        for i in 0..<960 {
            let stage: SleepStage = i < 100 ? .awake : .n2
            epochs.append(SleepEpoch(sessionId: sessionId, timestamp: start.addingTimeInterval(Double(i) * 30), predictedStage: stage))
        }
        let session = SleepSession(profileId: UUID(), startAt: start, endAt: end, state: .stopped, epochs: epochs)
        XCTAssertGreaterThan(session.efficiency, 0.85)
    }

    func test_awakeningsCount() {
        let sessionId = UUID()
        let stages: [SleepStage] = [.awake, .n1, .n2, .awake, .n2, .n3, .awake, .n2]
        let epochs = stages.enumerated().map { i, stage in
            SleepEpoch(sessionId: sessionId, timestamp: Date().addingTimeInterval(Double(i) * 30), predictedStage: stage)
        }
        let session = SleepSession(profileId: UUID(), startAt: Date(), state: .recording, epochs: epochs)
        XCTAssertEqual(session.awakeningsCount, 2)
    }

    func test_stageBreakdown() {
        let sessionId = UUID()
        let epochs = [
            SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .n2),
            SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .n2),
            SleepEpoch(sessionId: sessionId, timestamp: Date(), predictedStage: .n3),
        ]
        let session = SleepSession(profileId: UUID(), startAt: Date(), state: .recording, epochs: epochs)
        XCTAssertEqual(session.stageBreakdown[.n2], 60.0)
        XCTAssertEqual(session.stageBreakdown[.n3], 30.0)
    }
}
