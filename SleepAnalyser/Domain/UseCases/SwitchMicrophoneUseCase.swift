import Foundation

final class SwitchMicrophoneUseCase: Sendable {
    private let captureService: any AudioCaptureServiceProtocol
    private let profileRepo: any ProfileRepositoryProtocol

    init(captureService: any AudioCaptureServiceProtocol,
         profileRepo: any ProfileRepositoryProtocol) {
        self.captureService = captureService
        self.profileRepo = profileRepo
    }

    func execute(deviceUID: String, profileId: UUID) async throws {
        try await captureService.switchDevice(uid: deviceUID)

        guard var profile = try await profileRepo.getProfile(id: profileId) else {
            throw SleepSessionError.profileNotFound
        }
        profile.preferredInputDeviceUID = deviceUID
        try await profileRepo.updateProfile(profile)
    }
}
