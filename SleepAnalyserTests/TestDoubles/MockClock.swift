import Foundation
@testable import SleepAnalyser

final class MockSleepInferenceEngine: SleepInferenceEngineProtocol, @unchecked Sendable {
    var stubbedPrediction: StagePrediction?
    var recordedFeatures: [FeatureVector] = []

    func predict(features: FeatureVector, context: [String]) -> StagePrediction {
        recordedFeatures.append(features)
        return stubbedPrediction ?? StagePrediction(stage: .n2, confidence: 0.7, alternativeStages: [])
    }
}

final class MockClock: ClockProtocol, @unchecked Sendable {
    var currentDate: Date

    init(date: Date = Date()) {
        self.currentDate = date
    }

    func now() -> Date { currentDate }

    func advance(by interval: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(interval)
    }
}
