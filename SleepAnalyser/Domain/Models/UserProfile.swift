import Foundation

struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var preferredInputDeviceUID: String?
    var sensitivityPreset: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        preferredInputDeviceUID: String? = nil,
        sensitivityPreset: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.preferredInputDeviceUID = preferredInputDeviceUID
        self.sensitivityPreset = sensitivityPreset
        self.createdAt = createdAt
    }
}
