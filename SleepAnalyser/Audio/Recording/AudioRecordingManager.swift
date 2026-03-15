import Foundation
import AVFoundation
import Accelerate

final class AudioRecordingManager: @unchecked Sendable {
    private let storageDir: URL
    private var ringBuffer: [Float] = []
    private let ringBufferMaxSeconds: Double = 6.0
    private let sampleRate: Double = 16000.0
    private var fullNightWriter: AudioFileWriter?
    private var amplitudeSamples: [Float] = []
    private let amplitudeDownsampleRate = 10

    var fullNightRecordingURL: URL? { fullNightWriter?.url }
    var nightAmplitudes: [Float] { amplitudeSamples }
    private var frameCounter = 0

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func startNightRecording(sessionId: UUID) throws {
        let url = storageDir.appendingPathComponent("\(sessionId.uuidString)_full.caf")
        fullNightWriter = try AudioFileWriter(url: url, sampleRate: sampleRate)
        ringBuffer = []
        amplitudeSamples = []
        frameCounter = 0
    }

    func feedAudio(_ samples: [Float]) {
        let maxSamples = Int(ringBufferMaxSeconds * sampleRate)
        ringBuffer.append(contentsOf: samples)
        if ringBuffer.count > maxSamples {
            ringBuffer.removeFirst(ringBuffer.count - maxSamples)
        }

        fullNightWriter?.write(samples)

        frameCounter += 1
        if frameCounter % amplitudeDownsampleRate == 0 {
            var rms: Float = 0
            if !samples.isEmpty {
                vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
            }
            amplitudeSamples.append(rms)
        }
    }

    func captureEventClip(eventId: UUID, eventTime: Date, sessionStart: Date, bufferSeconds: Double = 2.0) -> URL? {
        let clipSamples = Int(bufferSeconds * 2 * sampleRate + sampleRate)
        guard ringBuffer.count > 0 else { return nil }
        let clipData = Array(ringBuffer.suffix(min(clipSamples, ringBuffer.count)))

        let url = storageDir.appendingPathComponent("\(eventId.uuidString)_clip.caf")
        guard let writer = try? AudioFileWriter(url: url, sampleRate: sampleRate) else { return nil }
        writer.write(clipData)
        writer.close()
        return url
    }

    func stopNightRecording() {
        fullNightWriter?.close()
        fullNightWriter = nil
    }

    func deleteClip(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func deleteNightRecording(sessionId: UUID) {
        let url = storageDir.appendingPathComponent("\(sessionId.uuidString)_full.caf")
        try? FileManager.default.removeItem(at: url)
    }

    func nightRecordingURL(for sessionId: UUID) -> URL? {
        let url = storageDir.appendingPathComponent("\(sessionId.uuidString)_full.caf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func allRecordings() -> [(sessionId: String, url: URL, size: Int64, date: Date)] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return [] }
        return files.filter { $0.lastPathComponent.hasSuffix("_full.caf") }.compactMap { url in
            let sessionId = url.lastPathComponent.replacingOccurrences(of: "_full.caf", with: "")
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let date = (attrs?[.creationDate] as? Date) ?? Date()
            return (sessionId, url, size, date)
        }.sorted { $0.date > $1.date }
    }
}

final class AudioFileWriter {
    let url: URL
    private var audioFile: ExtAudioFileRef?

    init(url: URL, sampleRate: Double) throws {
        self.url = url
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0
        )
        let status = ExtAudioFileCreateWithURL(url as CFURL, kAudioFileCAFType, &asbd, nil, AudioFileFlags.eraseFile.rawValue, &audioFile)
        guard status == noErr else { throw AudioCaptureError.engineStartFailed(NSError(domain: "AudioFileWriter", code: Int(status))) }
    }

    func write(_ samples: [Float]) {
        guard let audioFile, !samples.isEmpty else { return }
        var mutableSamples = samples
        let frameCount = UInt32(samples.count)
        var buffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: frameCount * 4, mData: &mutableSamples)
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        ExtAudioFileWrite(audioFile, frameCount, &bufferList)
    }

    func close() {
        guard let audioFile else { return }
        ExtAudioFileDispose(audioFile)
        self.audioFile = nil
    }

    deinit { close() }
}
