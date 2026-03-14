import Foundation
import Observation

@Observable
final class PipelineMetrics: @unchecked Sendable {
    var processingLatencyMs: Double = 0
    var cpuUsagePercent: Double = 0
    var bufferOverruns: Int = 0
    var droppedFrames: Int = 0
    var epochsProcessed: Int = 0

    func recordLatency(_ ms: Double) { processingLatencyMs = ms }
    func recordOverrun() { bufferOverruns += 1 }
    func recordDroppedFrame() { droppedFrames += 1 }
    func recordEpoch() { epochsProcessed += 1 }

    func reset() {
        processingLatencyMs = 0
        cpuUsagePercent = 0
        bufferOverruns = 0
        droppedFrames = 0
        epochsProcessed = 0
    }
}
