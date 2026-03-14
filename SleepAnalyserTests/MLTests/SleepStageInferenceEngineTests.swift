import XCTest
@testable import SleepAnalyser

final class SleepStageInferenceEngineTests: XCTestCase {
    let sut = SleepStageInferenceEngine()

    func test_deepSleep_lowRespRateHighRegularity() {
        let features = makeFeatures(breathingPeriodicity: 8, breathIntervalVariability: 0.1)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .n3)
    }

    func test_awake_veryHighRespRate() {
        let features = makeFeatures(breathingPeriodicity: 20, breathIntervalVariability: 0.5)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .awake)
    }

    func test_rem_highRespRateLowRegularity() {
        let features = makeFeatures(breathingPeriodicity: 15, breathIntervalVariability: 0.7)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .rem)
    }

    func test_n2_mediumRespRateMediumRegularity() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .n2)
    }

    func test_confidenceRange() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3)
        let result = sut.predict(features: features, context: [])
        XCTAssertGreaterThanOrEqual(result.confidence, 0)
        XCTAssertLessThanOrEqual(result.confidence, 1)
    }

    func test_highNoise_reducesConfidence() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3)
        let normal = sut.predict(features: features, context: [])
        let noisy = sut.predict(features: features, context: ["high_noise"])
        XCTAssertLessThan(noisy.confidence, normal.confidence)
    }

    func test_alternativeStagesProvided() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.alternativeStages.count, 4)
    }

    private func makeFeatures(breathingPeriodicity: Float, breathIntervalVariability: Float) -> FeatureVector {
        FeatureVector(
            timestamp: Date(),
            mfccCoefficients: [Float](repeating: 0, count: 13),
            spectralCentroid: 500, spectralRolloff: 0.8,
            spectralFlatness: 0.5, zeroCrossingRate: 0.1,
            rmsEnergy: 0.05,
            breathingPeriodicity: breathingPeriodicity,
            breathIntervalVariability: breathIntervalVariability
        )
    }
}
