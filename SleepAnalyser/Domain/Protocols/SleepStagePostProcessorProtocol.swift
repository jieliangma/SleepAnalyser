import Foundation

protocol SleepStagePostProcessorProtocol: Sendable {
    func smooth(prediction: StagePrediction, history: [SleepEpoch]) -> SleepStage
}
