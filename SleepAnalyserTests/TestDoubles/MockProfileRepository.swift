import Foundation
@testable import SleepAnalyser

final class MockProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    var profiles: [UUID: UserProfile] = [:]
    var calibrations: [UUID: AcousticCalibration] = [:]

    func createProfile(_ profile: UserProfile) async throws {
        profiles[profile.id] = profile
    }

    func getProfile(id: UUID) async throws -> UserProfile? {
        profiles[id]
    }

    func updateProfile(_ profile: UserProfile) async throws {
        profiles[profile.id] = profile
    }

    func deleteProfile(id: UUID) async throws {
        profiles.removeValue(forKey: id)
    }

    func getAllProfiles() async throws -> [UserProfile] {
        Array(profiles.values)
    }

    func getDefaultProfile() async throws -> UserProfile? {
        profiles.values.sorted { $0.createdAt < $1.createdAt }.first
    }

    func saveCalibration(_ calibration: AcousticCalibration) async throws {
        calibrations[calibration.profileId] = calibration
    }

    func getCalibration(profileId: UUID) async throws -> AcousticCalibration? {
        calibrations[profileId]
    }
}
