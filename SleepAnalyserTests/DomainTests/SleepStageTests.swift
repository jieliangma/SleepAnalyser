import XCTest
@testable import SleepAnalyser

final class SleepStageTests: XCTestCase {
    func test_allCasesExist() {
        let cases = SleepStage.allCases
        XCTAssertEqual(cases.count, 6)
        XCTAssertTrue(cases.contains(.awake))
        XCTAssertTrue(cases.contains(.n1))
        XCTAssertTrue(cases.contains(.n2))
        XCTAssertTrue(cases.contains(.n3))
        XCTAssertTrue(cases.contains(.rem))
        XCTAssertTrue(cases.contains(.unknown))
    }

    func test_displayNames() {
        XCTAssertEqual(SleepStage.awake.displayName, "Awake")
        XCTAssertEqual(SleepStage.n3.displayName, "Deep Sleep (N3)")
        XCTAssertEqual(SleepStage.rem.displayName, "REM Sleep")
    }

    func test_ordering_awakeHighest() {
        XCTAssertTrue(SleepStage.awake > SleepStage.rem)
        XCTAssertTrue(SleepStage.rem > SleepStage.n1)
        XCTAssertTrue(SleepStage.n1 > SleepStage.n2)
        XCTAssertTrue(SleepStage.n2 > SleepStage.n3)
    }

    func test_isAsleep() {
        XCTAssertFalse(SleepStage.awake.isAsleep)
        XCTAssertTrue(SleepStage.n1.isAsleep)
        XCTAssertTrue(SleepStage.n2.isAsleep)
        XCTAssertTrue(SleepStage.n3.isAsleep)
        XCTAssertTrue(SleepStage.rem.isAsleep)
        XCTAssertFalse(SleepStage.unknown.isAsleep)
    }

    func test_codableRoundTrip() throws {
        for stage in SleepStage.allCases {
            let data = try JSONEncoder().encode(stage)
            let decoded = try JSONDecoder().decode(SleepStage.self, from: data)
            XCTAssertEqual(stage, decoded)
        }
    }
}
