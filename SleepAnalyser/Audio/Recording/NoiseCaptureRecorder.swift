import Foundation
import AVFoundation
import Accelerate

final class NoiseCaptureRecorder: @unchecked Sendable {
    private let storageDir: URL
    private let sampleRate: Double = 16000.0
    private var writer: AudioFileWriter?
    private var sessionDir: URL?
    private(set) var amplitudes: [Float] = []
    private var frameCounter = 0
    private let amplitudeRate = 1
    private(set) var captureId: UUID?
    private(set) var startTime: Date?
    private var totalSamplesWritten: Int = 0

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/NoiseCaptures", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func startCapture() throws -> UUID {
        let id = UUID()
        captureId = id
        startTime = Date()
        amplitudes = []
        frameCounter = 0
        totalSamplesWritten = 0

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dirName = formatter.string(from: Date())
        let dir = storageDir.appendingPathComponent(dirName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sessionDir = dir

        let meta: [String: String] = ["captureId": id.uuidString, "startDate": ISO8601DateFormatter().string(from: Date())]
        try JSONSerialization.data(withJSONObject: meta).write(to: dir.appendingPathComponent("capture.json"))

        let audioURL = dir.appendingPathComponent("audio.m4a")
        writer = try AudioFileWriter(url: audioURL, sampleRate: sampleRate)
        return id
    }

    func feedAudio(_ samples: [Float]) {
        writer?.write(samples)
        totalSamplesWritten += samples.count
        frameCounter += 1
        if frameCounter % amplitudeRate == 0 {
            var rms: Float = 0
            if !samples.isEmpty { vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count)) }
            amplitudes.append(rms)
        }
    }

    func stopCapture() {
        writer?.close()
        writer = nil
        if let dir = sessionDir {
            let ampData = amplitudes.withUnsafeBufferPointer { Data(buffer: $0) }
            try? ampData.write(to: dir.appendingPathComponent("amplitudes.bin"))

            let duration = Double(totalSamplesWritten) / sampleRate
            let metaURL = dir.appendingPathComponent("capture.json")
            if var meta = (try? JSONSerialization.jsonObject(with: Data(contentsOf: metaURL))) as? [String: String] {
                meta["duration"] = String(duration)
                if let data = try? JSONSerialization.data(withJSONObject: meta) {
                    try? data.write(to: metaURL)
                }
            }
        }
    }

    func audioURL(for captureDir: URL) -> URL? {
        let m4a = captureDir.appendingPathComponent("audio.m4a")
        if FileManager.default.fileExists(atPath: m4a.path) { return m4a }
        let caf = captureDir.appendingPathComponent("audio.caf")
        if FileManager.default.fileExists(atPath: caf.path) { return caf }
        return nil
    }

    func extractClip(from captureDir: URL, startTime: TimeInterval, endTime: TimeInterval, clipId: UUID) -> URL? {
        guard let sourceURL = audioURL(for: captureDir) else { return nil }
        let clipURL = captureDir.appendingPathComponent("clip_\(clipId.uuidString.prefix(8)).m4a")

        guard let sourceFile = try? AVAudioFile(forReading: sourceURL) else { return nil }
        let sr = sourceFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startTime * sr)
        let frameCount = AVAudioFrameCount((endTime - startTime) * sr)
        guard frameCount > 0, startFrame >= 0, startFrame + AVAudioFramePosition(frameCount) <= sourceFile.length else { return nil }

        sourceFile.framePosition = startFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: frameCount) else { return nil }
        do {
            try sourceFile.read(into: buffer, frameCount: frameCount)
            let outFile = try AVAudioFile(forWriting: clipURL, settings: sourceFile.fileFormat.settings)
            try outFile.write(from: buffer)
            return clipURL
        } catch {
            return nil
        }
    }

    func loadAmplitudes(from captureDir: URL) -> [Float] {
        let url = captureDir.appendingPathComponent("amplitudes.bin")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    struct CaptureInfo: Identifiable, Hashable {
        let id: UUID
        let directoryURL: URL
        let date: Date
        let size: Int64
        let duration: TimeInterval

        static func == (lhs: CaptureInfo, rhs: CaptureInfo) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    func allCaptures() -> [CaptureInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return contents.compactMap { item -> CaptureInfo? in
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { return nil }
            let metaURL = item.appendingPathComponent("capture.json")
            guard let data = try? Data(contentsOf: metaURL),
                  let meta = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let idStr = meta["captureId"], let id = UUID(uuidString: idStr),
                  let dateStr = meta["startDate"], let date = ISO8601DateFormatter().date(from: dateStr) else { return nil }
            let audioFile = audioURL(for: item) ?? item.appendingPathComponent("audio.m4a")
            let size = Int64((try? FileManager.default.attributesOfItem(atPath: audioFile.path)[.size] as? Int) ?? 0)
            var duration = Double(meta["duration"] ?? "0") ?? 0
            if duration <= 0 && size > 0 {
                duration = Double(size) / 4.0 / 16000.0
            }
            return CaptureInfo(id: id, directoryURL: item, date: date, size: size, duration: duration)
        }.sorted { $0.date > $1.date }
    }

    func deleteCapture(_ info: CaptureInfo) {
        try? FileManager.default.removeItem(at: info.directoryURL)
    }
}
