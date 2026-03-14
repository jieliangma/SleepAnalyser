import XCTest
@testable import SleepAnalyser

final class SleepScoreCalculatorTests: XCTestCase {
    let sut = SleepScoreCalculator()

    func test_perfectNight_scoresHigh() {
        let session = makeSession(
            sleepHours: 8, efficiency: 0.95,
            deepPercent: 0.20, remPercent: 0.25,
            awakenings: 0, disturbanceCount: 0
        )
        let score = sut.calculate(session: session)
        XCTAssertGreaterThan(score.overall, 85)
    }

    func test_shortSleep_penalizesDuration() {
        let session = makeSession(sleepHours: 4, efficiency: 0.9, deepPercent: 0.20, remPercent: 0.25, awakenings: 0, disturbanceCount: 0)
        let score = sut.calculate(session: session)
        XCTAssertLessThan(score.durationScore, 70)
    }

    func test_manyAwakenings_penalizesDisturbances() {
        let session = makeSession(sleepHours: 8, efficiency: 0.9, deepPercent: 0.20, remPercent: 0.25, awakenings: 5, disturbanceCount: 3)
        let score = sut.calculate(session: session)
        XCTAssertLessThan(score.disturbanceScore, 60)
    }

    func test_scoreClamped0to100() {
        let session = makeSession(sleepHours: 2, efficiency: 0.3, deepPercent: 0.02, remPercent: 0.05, awakenings: 10, disturbanceCount: 10)
        let score = sut.calculate(session: session)
        XCTAssertGreaterThanOrEqual(score.overall, 0)
        XCTAssertLessThanOrEqual(score.overall, 100)
    }

    func test_lowDeepSleep_penalizesStageBalance() {
        let session = makeSession(sleepHours: 8, efficiency: 0.9, deepPercent: 0.05, remPercent: 0.25, awakenings: 0, disturbanceCount: 0)
        let score = sut.calculate(session: session)
        XCTAssertLessThan(score.stageBalanceScore, 80)
    }

    private func makeSession(sleepHours: Double, efficiency: Double, deepPercent: Double, remPercent: Double, awakenings: Int, disturbanceCount: Int) -> SleepSession {
        let sessionId = UUID()
        let start = Date()
        let totalDuration = sleepHours / efficiency
        let end = start.addingTimeInterval(totalDuration * 3600)

        let epochCount = Int(sleepHours * 3600 / 30)
        let deepCount = Int(Double(epochCount) * deepPercent)
        let remCount = Int(Double(epochCount) * remPercent)
        let awakeCount = awakenings * 2
        let lightCount = epochCount - deepCount - remCount - awakeCount

        var epochs = [SleepEpoch]()
        var time = start

        func addEpochs(_ count: Int, _ stage: SleepStage) {
            for _ in 0..<count {
                epochs.append(SleepEpoch(sessionId: sessionId, timestamp: time, predictedStage: stage))
                time = time.addingTimeInterval(30)
            }
        }

        addEpochs(lightCount, .n2)
        addEpochs(deepCount, .n3)
        addEpochs(remCount, .rem)
        for _ in 0..<awakenings {
            addEpochs(1, .awake)
            addEpochs(1, .n2)
        }

        var events = [AudioEvent]()
        for i in 0..<disturbanceCount {
            events.append(AudioEvent(sessionId: sessionId, eventType: .disturbance, startAt: start.addingTimeInterval(Double(i) * 3600), endAt: start.addingTimeInterval(Double(i) * 3600 + 5)))
        }

        return SleepSession(id: sessionId, profileId: UUID(), startAt: start, endAt: end, state: .stopped, epochs: epochs, events: events)
    }
}
