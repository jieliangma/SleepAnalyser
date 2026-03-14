import Foundation

final class CalibrateRoomAcousticsUseCase: Sendable {
    private let captureService: any AudioCaptureServiceProtocol
    private let preprocessor: any AudioPreprocessorProtocol
    private let profileRepo: any ProfileRepositoryProtocol
    private let clock: any ClockProtocol

    init(captureService: any AudioCaptureServiceProtocol,
         preprocessor: any AudioPreprocessorProtocol,
         profileRepo: any ProfileRepositoryProtocol,
         clock: any ClockProtocol = SystemClock()) {
        self.captureService = captureService
        self.preprocessor = preprocessor
        self.profileRepo = profileRepo
        self.clock = clock
    }

    // Records ~10 seconds of ambient audio and computes baseline noise profile
    func execute(profileId: UUID) async throws -> AcousticCalibration {
        try await captureService.startCapture()

        var noiseLevels: [Double] = []
        let calibrationDuration: TimeInterval = 10.0
        let startTime = clock.now()

        for await frame in captureService.audioStream {
            let processed = preprocessor.process(frame: frame)
            noiseLevels.append(processed.noiseLevel)

            if clock.now().timeIntervalSince(startTime) >= calibrationDuration {
                break
            }
        }

        captureService.stopCapture()

        let avgNoise = noiseLevels.isEmpty ? -50.0 : noiseLevels.reduce(0, +) / Double(noiseLevels.count)
        let gainFactor = max(0.5, min(2.0, -30.0 / avgNoise))

        let calibration = AcousticCalibration(
            profileId: profileId,
            baselineNoiseLevel: avgNoise,
            micGainFactor: gainFactor,
            lastCalibratedAt: clock.now()
        )

        try await profileRepo.saveCalibration(calibration)
        return calibration
    }
}
