import Foundation

struct SleepEpoch: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let timestamp: Date
    var predictedStage: SleepStage
    var confidence: Double
    var respirationRate: Double
    var snoreIntensity: Double
    var contextFlags: [String]

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date,
        predictedStage: SleepStage,
        confidence: Double = 0.0,
        respirationRate: Double = 0.0,
        snoreIntensity: Double = 0.0,
        contextFlags: [String] = []
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.predictedStage = predictedStage
        self.confidence = confidence
        self.respirationRate = respirationRate
        self.snoreIntensity = snoreIntensity
        self.contextFlags = contextFlags
    }

    var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel(rawConfidence: confidence)
    }

    var hasSnoring: Bool {
        snoreIntensity > 0.1
    }

    static let epochDuration: TimeInterval = 30.0
}
