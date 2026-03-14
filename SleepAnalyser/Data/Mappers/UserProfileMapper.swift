import Foundation

enum UserProfileMapper {
    static func toDomain(_ sd: SDUserProfile) -> UserProfile {
        UserProfile(
            id: sd.id, name: sd.name,
            preferredInputDeviceUID: sd.preferredInputDeviceUID,
            sensitivityPreset: sd.sensitivityPreset, createdAt: sd.createdAt
        )
    }

    static func toSD(_ domain: UserProfile) -> SDUserProfile {
        SDUserProfile(
            id: domain.id, name: domain.name,
            preferredInputDeviceUID: domain.preferredInputDeviceUID,
            sensitivityPreset: domain.sensitivityPreset, createdAt: domain.createdAt
        )
    }

    static func update(_ sd: SDUserProfile, from domain: UserProfile) {
        sd.name = domain.name
        sd.preferredInputDeviceUID = domain.preferredInputDeviceUID
        sd.sensitivityPreset = domain.sensitivityPreset
    }
}
