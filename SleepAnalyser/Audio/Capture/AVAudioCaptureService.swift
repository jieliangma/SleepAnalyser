import Foundation
import AVFoundation

enum AudioCaptureError: Error, LocalizedError {
    case engineStartFailed(Error)
    case deviceNotFound
    case permissionDenied
    case formatMismatch

    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let e): return "Audio engine failed to start: \(e.localizedDescription)"
        case .deviceNotFound: return "Audio input device not found"
        case .permissionDenied: return "Microphone permission denied"
        case .formatMismatch: return "Audio format mismatch"
        }
    }
}

final class AVAudioCaptureService: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private let deviceManager: AVAudioInputDeviceManager
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private var _audioStream: AsyncStream<AudioFrame>?
    private let targetSampleRate: Double = 16000.0
    private let frameSize: Int = 1024

    private(set) var currentDevice: AudioInputDevice?
    var availableDevices: [AudioInputDevice] { deviceManager.availableDevices }

    var audioStream: AsyncStream<AudioFrame> {
        if let stream = _audioStream { return stream }
        let stream = AsyncStream<AudioFrame> { [weak self] continuation in
            self?.continuation = continuation
        }
        _audioStream = stream
        return stream
    }

    init(deviceManager: AVAudioInputDeviceManager) {
        self.deviceManager = deviceManager
    }

    func startCapture() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            throw AudioCaptureError.permissionDenied
        }
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { throw AudioCaptureError.permissionDenied }
        }

        let newEngine = AVAudioEngine()
        let inputNode = newEngine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            throw AudioCaptureError.deviceNotFound
        }

        let bufferSize = AVAudioFrameCount(frameSize)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, time in
            guard let self else { return }
            let samples = AudioTapBufferBridge.extractMonoSamples(from: buffer)
            let resampled = AudioTapBufferBridge.resample(
                samples: samples,
                fromRate: hardwareFormat.sampleRate,
                toRate: self.targetSampleRate
            )
            let frame = AudioFrame(
                timestamp: Date(),
                samples: resampled,
                sampleRate: self.targetSampleRate,
                channelCount: 1
            )
            self.continuation?.yield(frame)
        }

        do {
            try newEngine.start()
        } catch {
            throw AudioCaptureError.engineStartFailed(error)
        }

        engine = newEngine
        if let device = deviceManager.availableDevices.first {
            currentDevice = device
        }
    }

    func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        continuation?.finish()
        continuation = nil
        _audioStream = nil
    }

    func switchDevice(uid: String) async throws {
        guard deviceManager.availableDevices.contains(where: { $0.id == uid }) else {
            throw AudioCaptureError.deviceNotFound
        }
        stopCapture()
        currentDevice = deviceManager.availableDevices.first(where: { $0.id == uid })
        try await startCapture()
    }
}
