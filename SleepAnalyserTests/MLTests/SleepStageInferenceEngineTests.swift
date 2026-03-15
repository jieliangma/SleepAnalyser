import XCTest
@testable import SleepAnalyser

final class SleepStageInferenceEngineTests: XCTestCase {
    let sut = SleepStageInferenceEngine()

    func test_predict_returnsValidStage() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3)
        let result = sut.predict(features: features, context: [])
        XCTAssertTrue(SleepStage.allCases.contains(result.stage))
    }

    func test_predict_deepSleepFeatures_notAwake() {
        let features = makeFeatures(breathingPeriodicity: 8, breathIntervalVariability: 0.1, rmsEnergy: 0.02)
        let result = sut.predict(features: features, context: [])
        XCTAssertTrue(result.stage.isAsleep)
    }

    func test_predict_highEnergyHighRate_likelyAwake() {
        let features = makeFeatures(breathingPeriodicity: 20, breathIntervalVariability: 0.5, rmsEnergy: 0.3)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .awake)
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
        XCTAssertGreaterThanOrEqual(result.alternativeStages.count, 1)
    }

    func test_predict_veryLowEnergy_awake() {
        let features = makeFeatures(breathingPeriodicity: 12, breathIntervalVariability: 0.3, rmsEnergy: 0.001)
        let result = sut.predict(features: features, context: [])
        XCTAssertEqual(result.stage, .awake)
    }

    private func makeFeatures(breathingPeriodicity: Float, breathIntervalVariability: Float, rmsEnergy: Float = 0.05) -> FeatureVector {
        FeatureVector(
            timestamp: Date(),
            mfccCoefficients: [Float](repeating: 0, count: 13),
            spectralCentroid: 500, spectralRolloff: 0.8,
            spectralFlatness: 0.5, zeroCrossingRate: 0.1,
            rmsEnergy: rmsEnergy,
            breathingPeriodicity: breathingPeriodicity,
            breathIntervalVariability: breathIntervalVariability
        )
    }
}
