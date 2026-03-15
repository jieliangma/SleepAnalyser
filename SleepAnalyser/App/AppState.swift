import Foundation
import Observation
import AVFoundation

@Observable
final class AppState {
    static let shared = AppState()

    let persistence: PersistenceController
    let deviceManager: AVAudioInputDeviceManager
    let captureService: AVAudioCaptureService
    let pipeline: AudioPipelineCoordinator
    let inferenceEngine: SleepStageInferenceEngine
    let postProcessor: HMMPostProcessor
    let cycleConstraints: SleepCycleConstraintEngine
    let scoreCalculator: SleepScoreCalculator
    let reportGenerator: MorningReportGenerator
    let trendAggregator: TrendAggregator
    let sessionRepo: SessionRepository
    let profileRepo: ProfileRepository
    let recordingManager: AudioRecordingManager
    let audioPlayer: AudioPlayerService
    let roomRepo: RoomRepository
    let noiseCaptureRecorder: NoiseCaptureRecorder
    let mlRetrainer: MLAutoRetrainer

    var activeSession: SleepSession?
    var activeProfile: UserProfile?
    var currentStage: SleepStage = .unknown
    var currentBreathingRate: Double = 0
    var currentNoiseLevel: Double = -100
    var epochHistory: [SleepEpoch] = []
    var sessionEvents: [AudioEvent] = []
    var elapsedTime: TimeInterval = 0
    var isRecording: Bool { activeSession?.state == .recording }
    var micPermissionGranted = false
    var calibration: AcousticCalibration?
    var activeRoom: RoomProfile?
    var currentAmplitude: Double = 0
    var breathCount: Int = 0

    private var recordingTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    private init() {
        self.persistence = PersistenceController.shared
        self.deviceManager = AVAudioInputDeviceManager()
        self.captureService = AVAudioCaptureService(deviceManager: deviceManager)
        self.pipeline = AudioPipelineCoordinator()
        self.inferenceEngine = SleepStageInferenceEngine()
        self.postProcessor = HMMPostProcessor()
        self.cycleConstraints = SleepCycleConstraintEngine()
        self.scoreCalculator = SleepScoreCalculator()
        self.reportGenerator = MorningReportGenerator()
        self.trendAggregator = TrendAggregator()
        self.sessionRepo = SessionRepository(persistence: persistence)
        self.profileRepo = ProfileRepository(persistence: persistence)
        self.recordingManager = AudioRecordingManager()
        self.audioPlayer = AudioPlayerService()
        self.roomRepo = RoomRepository(persistence: persistence)
        self.noiseCaptureRecorder = NoiseCaptureRecorder()
        self.mlRetrainer = MLAutoRetrainer()

        Task { await loadActiveProfile() }
        checkMicPermission()
    }

    private func checkMicPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        micPermissionGranted = status == .authorized
    }

    func requestMicPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run { micPermissionGranted = granted }
    }

    func loadActiveProfile() async {
        if let profile = try? await profileRepo.getDefaultProfile() {
            await MainActor.run { activeProfile = profile }
        } else {
            let name = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
            let newProfile = UserProfile(name: name)
            try? await profileRepo.createProfile(newProfile)
            await MainActor.run { activeProfile = newProfile }
        }
        await loadActiveRoom()
    }

    func loadActiveRoom() async {
        guard let profileId = activeProfile?.id else { return }
        if let room = try? await roomRepo.getSelectedRoom(for: profileId) {
            await MainActor.run { activeRoom = room }
        }
    }

    func startSession() async throws {
        guard let profile = activeProfile else { return }
        guard !isRecording else { return }

        if !micPermissionGranted {
            await requestMicPermission()
            guard micPermissionGranted else { throw AudioCaptureError.permissionDenied }
        }

        let session = SleepSession(profileId: profile.id, startAt: Date(), state: .recording)
        try await sessionRepo.createSession(session)
        await MainActor.run {
            activeSession = session
            epochHistory = []
            sessionEvents = []
            currentStage = .unknown
            currentBreathingRate = 0
            elapsedTime = 0
            breathCount = 0
        }

        try await captureService.startCapture()
        try? recordingManager.startNightRecording(sessionId: session.id)
        let outputStream = pipeline.makeOutputStream()
        let realtimeStream = pipeline.makeRealtimeStream()

        startTimer()

        realtimeTask = Task { [weak self] in
            guard let self else { return }
            for await rtFrame in realtimeStream {
                guard self.activeSession?.state == .recording else { break }
                await MainActor.run {
                    self.currentAmplitude = Double(rtFrame.rmsLevel)
                    self.currentNoiseLevel = rtFrame.noiseDB
                    if rtFrame.isBreathPeak {
                        self.breathCount += 1
                    }
                }
            }
        }

        recordingTask = Task { [weak self] in
            guard let self else { return }
            let audioStream = self.captureService.audioStream
            Task {
                for await frame in audioStream {
                    guard let session = self.activeSession, session.state == .recording else { break }
                    self.recordingManager.feedAudio(frame.samples)
                    self.pipeline.processFrame(frame, sessionId: session.id)
                }
            }
            for await output in outputStream {
                guard let session = self.activeSession, session.state == .recording else { break }
                await self.processOutput(output, session: session)
            }
        }
    }

    func stopSession() async throws {
        recordingTask?.cancel()
        recordingTask = nil
        realtimeTask?.cancel()
        realtimeTask = nil
        timerTask?.cancel()
        timerTask = nil
        captureService.stopCapture()
        recordingManager.stopNightRecording()
        pipeline.reset()

        guard var session = activeSession else { return }
        session.state = .stopped
        session.endAt = Date()
        session.epochs = epochHistory
        session.events = sessionEvents
        try await sessionRepo.updateSession(session)
        await MainActor.run {
            activeSession = session
        }
    }

    @MainActor
    private func processOutput(_ output: PipelineOutput, session: SleepSession) async {
        let prediction = inferenceEngine.predict(features: output.features, context: output.contextFlags)
        let smoothed = postProcessor.smooth(prediction: prediction, history: epochHistory)

        let epoch = SleepEpoch(
            sessionId: session.id,
            timestamp: output.timestamp,
            predictedStage: smoothed,
            confidence: prediction.confidence,
            respirationRate: output.breathingSample.breathsPerMinute,
            snoreIntensity: 0,
            contextFlags: output.contextFlags
        )

        epochHistory.append(epoch)
        currentStage = smoothed
        currentBreathingRate = output.breathingSample.breathsPerMinute

        for var event in output.events {
            if let clipURL = recordingManager.captureEventClip(
                eventId: event.id, eventTime: event.startAt, sessionStart: session.startAt
            ) {
                event.audioClipURL = clipURL
            }
            sessionEvents.append(event)
            try? await sessionRepo.addEvent(event, toSession: session.id)
        }

        try? await sessionRepo.addEpoch(epoch, toSession: session.id)
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let session = self.activeSession, session.state == .recording else { break }
                await MainActor.run {
                    self.elapsedTime = Date().timeIntervalSince(session.startAt)
                }
            }
        }
    }

    func generateReport() -> MorningReport? {
        guard let session = activeSession, session.state == .stopped else { return nil }
        var s = session
        s.epochs = epochHistory
        s.events = sessionEvents
        return reportGenerator.generateMorningReport(session: s)
    }
}
