import Foundation

protocol SleepInferenceEngineProtocol: Sendable {
    func predict(features: FeatureVector, context: [String]) -> StagePrediction
}
