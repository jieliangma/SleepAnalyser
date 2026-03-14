import Foundation

protocol ProfileRepositoryProtocol: Sendable {
    func createProfile(_ profile: UserProfile) async throws
    func getProfile(id: UUID) async throws -> UserProfile?
    func updateProfile(_ profile: UserProfile) async throws
    func deleteProfile(id: UUID) async throws
    func getAllProfiles() async throws -> [UserProfile]
    func getDefaultProfile() async throws -> UserProfile?

    func saveCalibration(_ calibration: AcousticCalibration) async throws
    func getCalibration(profileId: UUID) async throws -> AcousticCalibration?
}
