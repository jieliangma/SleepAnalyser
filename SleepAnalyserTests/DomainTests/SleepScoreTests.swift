import XCTest
@testable import SleepAnalyser

final class SleepScoreTests: XCTestCase {
    func test_gradeA_for90to100() {
        let score = SleepScore(overall: 95, durationScore: 95, efficiencyScore: 95, stageBalanceScore: 95, disturbanceScore: 95)
        XCTAssertEqual(score.grade, "A")
    }

    func test_gradeB_for80to89() {
        let score = SleepScore(overall: 85, durationScore: 85, efficiencyScore: 85, stageBalanceScore: 85, disturbanceScore: 85)
        XCTAssertEqual(score.grade, "B")
    }

    func test_gradeC_for70to79() {
        let score = SleepScore(overall: 75, durationScore: 75, efficiencyScore: 75, stageBalanceScore: 75, disturbanceScore: 75)
        XCTAssertEqual(score.grade, "C")
    }

    func test_gradeD_for60to69() {
        let score = SleepScore(overall: 65, durationScore: 65, efficiencyScore: 65, stageBalanceScore: 65, disturbanceScore: 65)
        XCTAssertEqual(score.grade, "D")
    }

    func test_gradeF_below60() {
        let score = SleepScore(overall: 45, durationScore: 45, efficiencyScore: 45, stageBalanceScore: 45, disturbanceScore: 45)
        XCTAssertEqual(score.grade, "F")
    }

    func test_zeroPerfect() {
        XCTAssertEqual(SleepScore.zero.grade, "F")
        XCTAssertEqual(SleepScore.perfect.grade, "A")
    }

    func test_boundaryAt90() {
        let score = SleepScore(overall: 90, durationScore: 90, efficiencyScore: 90, stageBalanceScore: 90, disturbanceScore: 90)
        XCTAssertEqual(score.grade, "A")
    }
}
