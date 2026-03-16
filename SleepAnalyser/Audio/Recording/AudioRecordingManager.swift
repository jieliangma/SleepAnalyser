import Foundation
import AVFoundation
import Accelerate

final class AudioRecordingManager: @unchecked Sendable {
    private let storageDir: URL
    private var ringBuffer: [Float] = []
    private let ringBufferMaxSeconds: Double = 6.0
    private let sampleRate: Double = 16000.0

    private var currentSessionId: UUID?
    private var currentSessionDir: URL?
    private var currentWriter: AudioFileWriter?
    private var segmentIndex: Int = 0
    private var samplesInSegment: Int = 0
    private let segmentDurationSeconds = 600
    private var segmentSamples: Int { segmentDurationSeconds * Int(sampleRate) }

    private var amplitudeSamples: [Float] = []
    private let amplitudeDownsampleRate = 10
    private var frameCounter = 0

    var nightAmplitudes: [Float] { amplitudeSamples }

    private static let dirDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

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

        let dateStr = Self.dirDateFormatter.string(from: Date())
        let dirName = "\(dateStr)"
        let sessionDir = storageDir.appendingPathComponent(dirName, isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        currentSessionDir = sessionDir

        let meta: [String: String] = ["sessionId": sessionId.uuidString, "startDate": ISO8601DateFormatter().string(from: Date())]
        let metaData = try JSONSerialization.data(withJSONObject: meta)
        try metaData.write(to: sessionDir.appendingPathComponent("session.json"))

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
        guard let sessionDir = currentSessionDir else { return nil }
        let url = sessionDir.appendingPathComponent("clip_\(eventId.uuidString.prefix(8)).m4a")
        guard let writer = try? AudioFileWriter(url: url, sampleRate: sampleRate) else { return nil }
        writer.write(clipData)
        writer.close()
        return url
    }

    func stopNightRecording() {
        currentWriter?.close()
        currentWriter = nil
        currentSessionId = nil
        currentSessionDir = nil
    }

    func deleteClip(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func deleteNightRecording(sessionId: UUID) {
        if let dir = findSessionDir(sessionId) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func deleteAllRecordings() {
        try? FileManager.default.removeItem(at: storageDir)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func cleanupIfNeeded() {
        let maxSize = StorageSettings.maxSizeBytes
        let maxDays = StorageSettings.maxRetentionDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        var recordings = allRecordings()

        for rec in recordings where rec.date < cutoffDate {
            try? FileManager.default.removeItem(at: rec.directoryURL)
        }
        recordings = allRecordings()

        var totalSize = recordings.reduce(Int64(0)) { $0 + $1.totalSize }
        var idx = recordings.count - 1
        while totalSize > maxSize && idx >= 0 {
            let rec = recordings[idx]
            try? FileManager.default.removeItem(at: rec.directoryURL)
            totalSize -= rec.totalSize
            idx -= 1
        }
    }

    func segmentURLs(for sessionId: UUID) -> [URL] {
        guard let dir = findSessionDir(sessionId) else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { ($0.pathExtension == "m4a" || $0.pathExtension == "caf") && $0.lastPathComponent.hasPrefix("seg_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func nightRecordingExists(for sessionId: UUID) -> Bool {
        !segmentURLs(for: sessionId).isEmpty
    }

    struct RecordingInfo {
        let sessionId: UUID
        let directoryURL: URL
        let totalSize: Int64
        let date: Date
        let segmentCount: Int
    }

    func allRecordings() -> [RecordingInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }

        var results: [RecordingInfo] = []
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let metaURL = item.appendingPathComponent("session.json")
            guard let metaData = try? Data(contentsOf: metaURL),
                  let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: String],
                  let idStr = meta["sessionId"],
                  let sessionId = UUID(uuidString: idStr) else { continue }

            let segments = (try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil))?
                .filter { ($0.pathExtension == "m4a" || $0.pathExtension == "caf") && $0.lastPathComponent.hasPrefix("seg_") } ?? []
            guard !segments.isEmpty else { continue }

            let totalSize = segments.reduce(Int64(0)) { sum, url in
                sum + (Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0))
            }

            let datePart = String(item.lastPathComponent.prefix(15))
            let date = Self.dirDateFormatter.date(from: datePart)
                ?? (try? item.resourceValues(forKeys: [.creationDateKey]).creationDate)
                ?? Date()

            results.append(RecordingInfo(sessionId: sessionId, directoryURL: item, totalSize: totalSize, date: date, segmentCount: segments.count))
        }
        return results.sorted { $0.date > $1.date }
    }

    private func findSessionDir(_ sessionId: UUID) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        let targetId = sessionId.uuidString
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let metaURL = item.appendingPathComponent("session.json")
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               meta["sessionId"] == targetId {
                return item
            }
        }
        return nil
    }

    private func openNewSegment() throws {
        guard let sessionDir = currentSessionDir else { return }
        let filename = String(format: "seg_%04d.m4a", segmentIndex)
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

        var fileASBD = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0, mFramesPerPacket: 1024, mBytesPerFrame: 0,
            mChannelsPerFrame: 1, mBitsPerChannel: 0, mReserved: 0
        )

        let status = ExtAudioFileCreateWithURL(
            url as CFURL, kAudioFileM4AType, &fileASBD, nil,
            AudioFileFlags.eraseFile.rawValue, &audioFile
        )
        guard status == noErr, let audioFile else {
            throw AudioCaptureError.engineStartFailed(
                NSError(domain: "AudioFileWriter", code: Int(status))
            )
        }

        var clientASBD = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0
        )
        let clientStatus = ExtAudioFileSetProperty(
            audioFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientASBD
        )
        guard clientStatus == noErr else {
            ExtAudioFileDispose(audioFile)
            self.audioFile = nil
            throw AudioCaptureError.engineStartFailed(
                NSError(domain: "AudioFileWriter", code: Int(clientStatus))
            )
        }
        self.audioFile = audioFile
    }

    func write(_ samples: [Float]) {
        guard let audioFile, !samples.isEmpty else { return }
        var mutableSamples = samples
        let frameCount = UInt32(samples.count)
        mutableSamples.withUnsafeMutableBufferPointer { ptr in
            var buffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: frameCount * 4, mData: ptr.baseAddress)
            var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
            let status = ExtAudioFileWrite(audioFile, frameCount, &bufferList)
            if status != noErr {
                NSLog("AudioFileWriter: write failed with status %d", status)
            }
        }
    }

    func close() {
        guard let audioFile else { return }
        ExtAudioFileDispose(audioFile)
        self.audioFile = nil
    }

    deinit { close() }
}
