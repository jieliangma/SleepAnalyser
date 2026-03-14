import Foundation

final class ProcessAudioFrameUseCase: Sendable {
    private let preprocessor: any AudioPreprocessorProtocol
    private let featureExtractor: any FeatureExtractorProtocol
    private let inferenceEngine: any SleepInferenceEngineProtocol
    private let postProcessor: any SleepStagePostProcessorProtocol
    private let sessionRepo: any SessionRepositoryProtocol

    init(preprocessor: any AudioPreprocessorProtocol,
         featureExtractor: any FeatureExtractorProtocol,
         inferenceEngine: any SleepInferenceEngineProtocol,
         postProcessor: any SleepStagePostProcessorProtocol,
         sessionRepo: any SessionRepositoryProtocol) {
        self.preprocessor = preprocessor
        self.featureExtractor = featureExtractor
        self.inferenceEngine = inferenceEngine
        self.postProcessor = postProcessor
        self.sessionRepo = sessionRepo
    }

    func execute(frame: AudioFrame, sessionId: UUID, history: [SleepEpoch], contextFlags: [String]) async throws -> SleepEpoch {
        let processed = preprocessor.process(frame: frame)
        let features = featureExtractor.extractFeatures(from: processed)
        let prediction = inferenceEngine.predict(features: features, context: contextFlags)
        let smoothedStage = postProcessor.smooth(prediction: prediction, history: history)

        let epoch = SleepEpoch(
            sessionId: sessionId,
            timestamp: frame.timestamp,
            predictedStage: smoothedStage,
            confidence: prediction.confidence,
            respirationRate: Double(features.breathingPeriodicity),
            snoreIntensity: 0,
            contextFlags: contextFlags
        )

        try await sessionRepo.addEpoch(epoch, toSession: sessionId)
        return epoch
    }
}
