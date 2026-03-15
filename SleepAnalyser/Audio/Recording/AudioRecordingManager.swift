import Foundation
import AVFoundation
import Accelerate

final class AudioRecordingManager: @unchecked Sendable {
    private let storageDir: URL
    private var ringBuffer: [Float] = []
    private let ringBufferMaxSeconds: Double = 6.0
    private let sampleRate: Double = 16000.0

    private var currentSessionId: UUID?
    private var currentWriter: AudioFileWriter?
    private var segmentIndex: Int = 0
    private var samplesInSegment: Int = 0
    private let segmentDurationSeconds = 600
    private var segmentSamples: Int { segmentDurationSeconds * Int(sampleRate) }

    private var amplitudeSamples: [Float] = []
    private let amplitudeDownsampleRate = 10
    private var frameCounter = 0

    var nightAmplitudes: [Float] { amplitudeSamples }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func startNightRecording(sessionId: UUID) throws {
        currentSessionId = sessionId
        segmentIndex = 0
        samplesInSegment = 0
        amplitudeSamples = []
        frameCounter = 0
        ringBuffer = []

        let sessionDir = storageDir.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try openNewSegment()
    }

    func feedAudio(_ samples: [Float]) {
        let maxSamples = Int(ringBufferMaxSeconds * sampleRate)
        ringBuffer.append(contentsOf: samples)
        if ringBuffer.count > maxSamples {
            ringBuffer.removeFirst(ringBuffer.count - maxSamples)
        }

        if currentWriter != nil {
            currentWriter?.write(samples)
            samplesInSegment += samples.count
            if samplesInSegment >= segmentSamples {
                rotateSegment()
            }
        }

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
        guard !ringBuffer.isEmpty else { return nil }
        let clipData = Array(ringBuffer.suffix(min(clipSamples, ringBuffer.count)))

        let url = storageDir.appendingPathComponent("\(eventId.uuidString)_clip.caf")
        guard let writer = try? AudioFileWriter(url: url, sampleRate: sampleRate) else { return nil }
        writer.write(clipData)
        writer.close()
        return url
    }

    func stopNightRecording() {
        currentWriter?.close()
        currentWriter = nil
        currentSessionId = nil
    }

    func deleteClip(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func deleteNightRecording(sessionId: UUID) {
        let sessionDir = storageDir.appendingPathComponent(sessionId.uuidString)
        try? FileManager.default.removeItem(at: sessionDir)
        let legacyFile = storageDir.appendingPathComponent("\(sessionId.uuidString)_full.caf")
        try? FileManager.default.removeItem(at: legacyFile)
    }

    func segmentURLs(for sessionId: UUID) -> [URL] {
        let sessionDir = storageDir.appendingPathComponent(sessionId.uuidString)
        guard let files = try? FileManager.default.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil) else {
            let legacy = storageDir.appendingPathComponent("\(sessionId.uuidString)_full.caf")
            return FileManager.default.fileExists(atPath: legacy.path) ? [legacy] : []
        }
        return files.filter { $0.pathExtension == "caf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func nightRecordingExists(for sessionId: UUID) -> Bool {
        !segmentURLs(for: sessionId).isEmpty
    }

    func allRecordings() -> [(sessionId: String, url: URL, size: Int64, date: Date, segmentCount: Int)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey]) else { return [] }

        var results: [(String, URL, Int64, Date, Int)] = []

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                let sessionId = item.lastPathComponent
                let segments = (try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension == "caf" } ?? []
                guard !segments.isEmpty else { continue }
                let totalSize = segments.reduce(Int64(0)) { sum, url in
                    sum + (Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0))
                }
                let date = (try? item.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                results.append((sessionId, item, totalSize, date, segments.count))
            } else if item.lastPathComponent.hasSuffix("_full.caf") {
                let sessionId = item.lastPathComponent.replacingOccurrences(of: "_full.caf", with: "")
                let attrs = try? FileManager.default.attributesOfItem(atPath: item.path)
                let size = (attrs?[.size] as? Int64) ?? 0
                let date = (attrs?[.creationDate] as? Date) ?? Date()
                results.append((sessionId, item, size, date, 1))
            }
        }
        return results.sorted { $0.3 > $1.3 }
    }

    private func openNewSegment() throws {
        guard let sessionId = currentSessionId else { return }
        let sessionDir = storageDir.appendingPathComponent(sessionId.uuidString)
        let filename = String(format: "seg_%04d.caf", segmentIndex)
        let url = sessionDir.appendingPathComponent(filename)
        currentWriter = try AudioFileWriter(url: url, sampleRate: sampleRate)
        samplesInSegment = 0
    }

    private func rotateSegment() {
        currentWriter?.close()
        currentWriter = nil
        segmentIndex += 1
        try? openNewSegment()
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
        let status = ExtAudioFileWrite(audioFile, frameCount, &bufferList)
        if status != noErr {
            NSLog("AudioFileWriter: write failed with status %d", status)
        }
    }

    func close() {
        guard let audioFile else { return }
        ExtAudioFileDispose(audioFile)
        self.audioFile = nil
    }

    deinit { close() }
}
