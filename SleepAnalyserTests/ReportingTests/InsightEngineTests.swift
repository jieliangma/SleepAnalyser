import XCTest
@testable import SleepAnalyser

final class InsightEngineTests: XCTestCase {
    let sut = InsightEngine()

    override func setUp() {
        super.setUp()
        LanguageManager.shared.currentLanguage = .en
    }

    func test_lowDeepSleep_generatesInsight() {
        let session = makeSession(deepPercent: 0.05)
        let score = SleepScore(overall: 70, durationScore: 80, efficiencyScore: 80, stageBalanceScore: 50, disturbanceScore: 80)
        let insights = sut.generateInsights(session: session, score: score)
        XCTAssertTrue(insights.contains(where: { $0.lowercased().contains("deep sleep") }))
    }

    func test_manyDisturbances_generatesInsight() {
        let sessionId = UUID()
        let start = Date()
        var events = [AudioEvent]()
        for i in 0..<5 {
            events.append(AudioEvent(sessionId: sessionId, eventType: .disturbance, source: .traffic, startAt: start.addingTimeInterval(Double(i) * 600), endAt: start.addingTimeInterval(Double(i) * 600 + 10)))
        }
        let session = SleepSession(id: sessionId, profileId: UUID(), startAt: start, endAt: start.addingTimeInterval(28800), state: .stopped, events: events)
        let score = SleepScore(overall: 60, durationScore: 60, efficiencyScore: 60, stageBalanceScore: 60, disturbanceScore: 40)
        let insights = sut.generateInsights(session: session, score: score)
        XCTAssertTrue(insights.contains(where: { $0.lowercased().contains("traffic") || $0.lowercased().contains("disturbance") }))
    }

    func test_goodSleepDuration_generatesPositiveInsight() {
        let session = makeSession(sleepHours: 8)
        let score = SleepScore.perfect
        let insights = sut.generateInsights(session: session, score: score)
        XCTAssertTrue(insights.contains(where: { $0.lowercased().contains("great") || $0.lowercased().contains("good") }))
    }

    func test_noDuplicateInsights() {
        let session = makeSession(sleepHours: 8, deepPercent: 0.20)
        let score = SleepScore.perfect
        let insights = sut.generateInsights(session: session, score: score)
        let uniqueInsights = Set(insights)
        XCTAssertEqual(insights.count, uniqueInsights.count)
    }

    private func makeSession(sleepHours: Double = 7.5, deepPercent: Double = 0.15) -> SleepSession {
        let sessionId = UUID()
        let start = Date()
        let epochCount = Int(sleepHours * 120)
        let deepCount = Int(Double(epochCount) * deepPercent)

        var epochs = [SleepEpoch]()
        for i in 0..<epochCount {
            let stage: SleepStage = i < deepCount ? .n3 : .n2
            epochs.append(SleepEpoch(sessionId: sessionId, timestamp: start.addingTimeInterval(Double(i) * 30), predictedStage: stage))
        }

        return SleepSession(id: sessionId, profileId: UUID(), startAt: start, endAt: start.addingTimeInterval(sleepHours * 3600), state: .stopped, epochs: epochs)
    }
}
