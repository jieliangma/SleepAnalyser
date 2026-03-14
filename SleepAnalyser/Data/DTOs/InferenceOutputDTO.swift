import Foundation

struct InferenceOutputDTO: Codable, Sendable {
    let stage: String
    let confidence: Double
    let alternativeStages: [String: Double]
    let timestamp: Date

    init(from prediction: StagePrediction, timestamp: Date) {
        self.stage = prediction.stage.rawValue
        self.confidence = prediction.confidence
        self.alternativeStages = Dictionary(
            uniqueKeysWithValues: prediction.alternativeStages.map { ($0.0.rawValue, $0.1) }
        )
        self.timestamp = timestamp
    }
}
