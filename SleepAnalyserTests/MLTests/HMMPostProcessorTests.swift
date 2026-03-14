import XCTest
@testable import SleepAnalyser

final class HMMPostProcessorTests: XCTestCase {
    let sut = HMMPostProcessor()

    func test_smoothsJitterySequence() {
        let history = [
            makeEpoch(stage: .n2),
            makeEpoch(stage: .n2),
        ]
        let jitterPrediction = StagePrediction(stage: .awake, confidence: 0.3, alternativeStages: [])
        let result = sut.smooth(prediction: jitterPrediction, history: history)
        XCTAssertEqual(result, .n2)
    }

    func test_preventsImpossibleTransition_awakeToN3() {
        let history = [makeEpoch(stage: .awake)]
        let prediction = StagePrediction(stage: .n3, confidence: 0.4, alternativeStages: [])
        let result = sut.smooth(prediction: prediction, history: history)
        XCTAssertNotEqual(result, .n3)
    }

    func test_allowsValidTransition_n1ToN2() {
        let history = [makeEpoch(stage: .n1)]
        let prediction = StagePrediction(stage: .n2, confidence: 0.7, alternativeStages: [])
        let result = sut.smooth(prediction: prediction, history: history)
        XCTAssertEqual(result, .n2)
    }

    func test_emptyHistory_returnsRawPrediction() {
        let prediction = StagePrediction(stage: .n3, confidence: 0.8, alternativeStages: [])
        let result = sut.smooth(prediction: prediction, history: [])
        XCTAssertEqual(result, .n3)
    }

    func test_highConfidence_overridesSmoothing() {
        let history = [makeEpoch(stage: .n2)]
        let prediction = StagePrediction(stage: .rem, confidence: 0.9, alternativeStages: [])
        let result = sut.smooth(prediction: prediction, history: history)
        XCTAssertEqual(result, .rem)
    }

    private func makeEpoch(stage: SleepStage) -> SleepEpoch {
        SleepEpoch(sessionId: UUID(), timestamp: Date(), predictedStage: stage, confidence: 0.7)
    }
}
