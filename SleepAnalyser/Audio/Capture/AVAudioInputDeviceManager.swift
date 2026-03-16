import Foundation
import CoreAudio
import Combine

final class AVAudioInputDeviceManager: @unchecked Sendable {
    private var devices: [AudioInputDevice] = []
    private var outputDevices: [AudioOutputDevice] = []
    private let devicesSubject = CurrentValueSubject<[AudioInputDevice], Never>([])
    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?

    var availableDevices: [AudioInputDevice] { devices }
    var availableOutputDevices: [AudioOutputDevice] { outputDevices }
    var devicesPublisher: AnyPublisher<[AudioInputDevice], Never> { devicesSubject.eraseToAnyPublisher() }

    var defaultOutputDeviceID: AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioDeviceUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID)
        return deviceID
    }

    var defaultOutputDeviceUID: String {
        let id = defaultOutputDeviceID
        return id != kAudioDeviceUnknown ? (getDeviceUID(deviceID: id) ?? "") : ""
    }

    init() {
        refreshDevices()
        installDeviceChangeListener()
    }

    deinit {
        removeDeviceChangeListener()
    }

    func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize
        )
        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return }

        devices = deviceIDs.compactMap { deviceID -> AudioInputDevice? in
            guard hasInputStreams(deviceID: deviceID) else { return nil }
            let name = getDeviceName(deviceID: deviceID) ?? "Unknown"
            let uid = getDeviceUID(deviceID: deviceID) ?? "\(deviceID)"
            let sampleRate = getDeviceSampleRate(deviceID: deviceID)
            let channels = getInputChannelCount(deviceID: deviceID)
            return AudioInputDevice(id: uid, name: name, sampleRate: sampleRate, channelCount: channels)
        }

        outputDevices = deviceIDs.compactMap { deviceID -> AudioOutputDevice? in
            guard hasOutputStreams(deviceID: deviceID) else { return nil }
            let name = getDeviceName(deviceID: deviceID) ?? "Unknown"
            let uid = getDeviceUID(deviceID: deviceID) ?? "\(deviceID)"
            return AudioOutputDevice(id: uid, deviceID: deviceID, name: name)
        }

        devicesSubject.send(devices)
    }

    @discardableResult
    func setDefaultOutputDevice(uid: String) -> Bool {
        guard let device = outputDevices.first(where: { $0.id == uid }) else { return false }
        var deviceID = device.deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID
        )
        return status == noErr
    }

    private func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        return status == noErr ? name as String : nil
    }

    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
        return status == noErr ? uid as String : nil
    }

    private func getDeviceSampleRate(deviceID: AudioDeviceID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 44100.0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &sampleRate)
        return sampleRate
    }

    private func getInputChannelCount(deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPointer.deallocate() }

        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return 0 }

        let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self).pointee
        return Int(bufferList.mNumberBuffers) > 0 ? Int(bufferList.mBuffers.mNumberChannels) : 0
    }

    private func installDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDevices()
        }
        propertyListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
    }

    private func removeDeviceChangeListener() {
        guard let block = propertyListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
    }
}
