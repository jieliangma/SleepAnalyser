import Foundation
import SwiftData

@Model
final class SDSleepEpoch {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var timestamp: Date
    var stageRawValue: String
    var confidence: Double
    var respirationRate: Double
    var snoreIntensity: Double
    var contextFlagsJSON: String

    var session: SDSleepSession?

    init(id: UUID = UUID(), sessionId: UUID, timestamp: Date, stageRawValue: String = "unknown",
         confidence: Double = 0, respirationRate: Double = 0, snoreIntensity: Double = 0,
         contextFlagsJSON: String = "[]") {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.stageRawValue = stageRawValue
        self.confidence = confidence
        self.respirationRate = respirationRate
        self.snoreIntensity = snoreIntensity
        self.contextFlagsJSON = contextFlagsJSON
    }
}
