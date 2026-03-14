import Foundation
import SwiftData

@Model
final class SDUserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var preferredInputDeviceUID: String?
    var sensitivityPreset: Double
    var createdAt: Date

    init(id: UUID = UUID(), name: String, preferredInputDeviceUID: String? = nil,
         sensitivityPreset: Double = 1.0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.preferredInputDeviceUID = preferredInputDeviceUID
        self.sensitivityPreset = sensitivityPreset
        self.createdAt = createdAt
    }
}
