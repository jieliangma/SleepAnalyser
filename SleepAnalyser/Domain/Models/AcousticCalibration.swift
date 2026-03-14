import Foundation

struct AcousticCalibration: Codable, Sendable {
    let profileId: UUID
    var baselineNoiseLevel: Double
    var micGainFactor: Double
    var roomEchoProfile: Data?
    var lastCalibratedAt: Date

    init(
        profileId: UUID,
        baselineNoiseLevel: Double = -50.0,
        micGainFactor: Double = 1.0,
        roomEchoProfile: Data? = nil,
        lastCalibratedAt: Date = Date()
    ) {
        self.profileId = profileId
        self.baselineNoiseLevel = baselineNoiseLevel
        self.micGainFactor = micGainFactor
        self.roomEchoProfile = roomEchoProfile
        self.lastCalibratedAt = lastCalibratedAt
    }

    var isStale: Bool {
        lastCalibratedAt.timeIntervalSinceNow < -7 * 24 * 3600
    }
}
