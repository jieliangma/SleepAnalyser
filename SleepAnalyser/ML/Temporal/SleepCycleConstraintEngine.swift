import Foundation

final class SleepCycleConstraintEngine: Sendable {
    private let cycleDuration: TimeInterval = 5400

    func applyConstraints(epochs: [SleepEpoch], sessionStart: Date) -> [SleepEpoch] {
        guard !epochs.isEmpty else { return epochs }
        return epochs.map { epoch in
            var adjusted = epoch
            let elapsed = epoch.timestamp.timeIntervalSince(sessionStart)
            let cycleNumber = Int(elapsed / cycleDuration)
            let cyclePhase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

            if cycleNumber < 2 && epoch.predictedStage == .rem && epoch.confidence < 0.7 {
                adjusted.predictedStage = .n2
                adjusted.confidence *= 0.8
            }

            if cycleNumber >= 3 && epoch.predictedStage == .n3 && epoch.confidence < 0.7 {
                adjusted.predictedStage = .n2
                adjusted.confidence *= 0.8
            }

            if cyclePhase < 0.3 && epoch.predictedStage == .rem && epoch.confidence < 0.6 {
                adjusted.predictedStage = .n2
                adjusted.confidence *= 0.7
            }

            return adjusted
        }
    }
}
