import Foundation
import SwiftData

@Model
final class SDRoomProfile {
    @Attribute(.unique) var id: UUID
    var userProfileId: UUID
    var name: String
    var baselineNoiseLevel: Double
    var micGainFactor: Double
    var noiseFloorSpectrum: Data?
    var lastCalibratedAt: Date?
    var isSelected: Bool

    init(id: UUID = UUID(), userProfileId: UUID, name: String,
         baselineNoiseLevel: Double = -50, micGainFactor: Double = 1.0,
         noiseFloorSpectrum: Data? = nil, lastCalibratedAt: Date? = nil, isSelected: Bool = false) {
        self.id = id
        self.userProfileId = userProfileId
        self.name = name
        self.baselineNoiseLevel = baselineNoiseLevel
        self.micGainFactor = micGainFactor
        self.noiseFloorSpectrum = noiseFloorSpectrum
        self.lastCalibratedAt = lastCalibratedAt
        self.isSelected = isSelected
    }
}
