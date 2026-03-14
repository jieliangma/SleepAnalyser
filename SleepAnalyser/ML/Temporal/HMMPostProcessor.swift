import Foundation

// HMM transition matrix for physiologically plausible sleep stage sequences
final class HMMPostProcessor: Sendable {
    // transition[from][to] = probability
    private let transitionMatrix: [[Double]] = {
        // Order: awake(0), n1(1), n2(2), n3(3), rem(4)
        var m = [[Double]](repeating: [Double](repeating: 0.01, count: 5), count: 5)
        // From Awake
        m[0][0] = 0.70; m[0][1] = 0.25; m[0][2] = 0.03; m[0][3] = 0.01; m[0][4] = 0.01
        // From N1
        m[1][0] = 0.10; m[1][1] = 0.40; m[1][2] = 0.40; m[1][3] = 0.05; m[1][4] = 0.05
        // From N2
        m[2][0] = 0.05; m[2][1] = 0.10; m[2][2] = 0.45; m[2][3] = 0.25; m[2][4] = 0.15
        // From N3
        m[3][0] = 0.02; m[3][1] = 0.03; m[3][2] = 0.35; m[3][3] = 0.55; m[3][4] = 0.05
        // From REM
        m[4][0] = 0.10; m[4][1] = 0.15; m[4][2] = 0.20; m[4][3] = 0.05; m[4][4] = 0.50
        return m
    }()

    func smooth(prediction: StagePrediction, history: [SleepEpoch]) -> SleepStage {
        guard let lastEpoch = history.last else { return prediction.stage }

        let fromIndex = stageIndex(lastEpoch.predictedStage)
        let toIndex = stageIndex(prediction.stage)
        let transitionProb = transitionMatrix[fromIndex][toIndex]

        if transitionProb < 0.03 {
            return lastEpoch.predictedStage
        }

        if prediction.confidence > 0.6 || transitionProb > 0.2 {
            return prediction.stage
        }

        return lastEpoch.predictedStage
    }

    private func stageIndex(_ stage: SleepStage) -> Int {
        switch stage {
        case .awake:   return 0
        case .n1:      return 1
        case .n2:      return 2
        case .n3:      return 3
        case .rem:     return 4
        case .unknown: return 0
        }
    }
}
