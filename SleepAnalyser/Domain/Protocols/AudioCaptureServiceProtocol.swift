import Foundation

protocol AudioCaptureServiceProtocol: Sendable {
    func startCapture() async throws
    func stopCapture()
    var audioStream: AsyncStream<AudioFrame> { get }
    var currentDevice: AudioInputDevice? { get }
    var availableDevices: [AudioInputDevice] { get }
    func switchDevice(uid: String) async throws
}
