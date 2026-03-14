import Foundation

struct StagePrediction: Sendable {
    let stage: SleepStage
    let confidence: Double
    let alternativeStages: [(SleepStage, Double)]

    var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel(rawConfidence: confidence)
    }

    var bestAlternative: SleepStage? {
        alternativeStages.first?.0
    }
}
