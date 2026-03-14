import Foundation
import SwiftData

@Model
final class SDCalibration {
    @Attribute(.unique) var profileId: UUID
    var baselineNoiseLevel: Double
    var micGainFactor: Double
    var roomEchoProfile: Data?
    var lastCalibratedAt: Date

    init(profileId: UUID, baselineNoiseLevel: Double = -50, micGainFactor: Double = 1.0,
         roomEchoProfile: Data? = nil, lastCalibratedAt: Date = Date()) {
        self.profileId = profileId
        self.baselineNoiseLevel = baselineNoiseLevel
        self.micGainFactor = micGainFactor
        self.roomEchoProfile = roomEchoProfile
        self.lastCalibratedAt = lastCalibratedAt
    }
}
