import Foundation
import SwiftData

final class ProfileRepository: @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func createProfile(_ profile: UserProfile) async throws {
        let context = persistence.newBackgroundContext()
        context.insert(UserProfileMapper.toSD(profile))
        try context.save()
    }

    func getProfile(id: UUID) async throws -> UserProfile? {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDUserProfile> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first.map { UserProfileMapper.toDomain($0) }
    }

    func updateProfile(_ profile: UserProfile) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDUserProfile> { $0.id == profile.id }
        guard let sd = try context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
        UserProfileMapper.update(sd, from: profile)
        try context.save()
    }

    func deleteProfile(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDUserProfile> { $0.id == id }
        if let sd = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            context.delete(sd)
            try context.save()
        }
    }

    func getAllProfiles() async throws -> [UserProfile] {
        let context = persistence.newBackgroundContext()
        return try context.fetch(FetchDescriptor<SDUserProfile>()).map { UserProfileMapper.toDomain($0) }
    }

    func getDefaultProfile() async throws -> UserProfile? {
        let context = persistence.newBackgroundContext()
        var descriptor = FetchDescriptor<SDUserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { UserProfileMapper.toDomain($0) }
    }

    func saveCalibration(_ calibration: AcousticCalibration) async throws {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDCalibration> { $0.profileId == calibration.profileId }
        if let existing = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.baselineNoiseLevel = calibration.baselineNoiseLevel
            existing.micGainFactor = calibration.micGainFactor
            existing.roomEchoProfile = calibration.roomEchoProfile
            existing.lastCalibratedAt = calibration.lastCalibratedAt
        } else {
            context.insert(SDCalibration(
                profileId: calibration.profileId,
                baselineNoiseLevel: calibration.baselineNoiseLevel,
                micGainFactor: calibration.micGainFactor,
                roomEchoProfile: calibration.roomEchoProfile,
                lastCalibratedAt: calibration.lastCalibratedAt
            ))
        }
        try context.save()
    }

    func getCalibration(profileId: UUID) async throws -> AcousticCalibration? {
        let context = persistence.newBackgroundContext()
        let predicate = #Predicate<SDCalibration> { $0.profileId == profileId }
        guard let sd = try context.fetch(FetchDescriptor(predicate: predicate)).first else { return nil }
        return AcousticCalibration(
            profileId: sd.profileId, baselineNoiseLevel: sd.baselineNoiseLevel,
            micGainFactor: sd.micGainFactor, roomEchoProfile: sd.roomEchoProfile,
            lastCalibratedAt: sd.lastCalibratedAt
        )
    }
}
