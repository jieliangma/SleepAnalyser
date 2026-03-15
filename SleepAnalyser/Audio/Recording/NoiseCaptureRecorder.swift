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
    private let amplitudeRate = 5
    private(set) var captureId: UUID?
    private(set) var startTime: Date?

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

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dirName = formatter.string(from: Date())
        let dir = storageDir.appendingPathComponent(dirName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sessionDir = dir

        let meta: [String: String] = ["captureId": id.uuidString, "startDate": ISO8601DateFormatter().string(from: Date())]
        try JSONSerialization.data(withJSONObject: meta).write(to: dir.appendingPathComponent("capture.json"))

        let audioURL = dir.appendingPathComponent("audio.caf")
        writer = try AudioFileWriter(url: audioURL, sampleRate: sampleRate)
        return id
    }

    func feedAudio(_ samples: [Float]) {
        writer?.write(samples)
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
        }
    }

    func audioURL(for captureDir: URL) -> URL? {
        let url = captureDir.appendingPathComponent("audio.caf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
            let audioFile = item.appendingPathComponent("audio.caf")
            let size = Int64((try? FileManager.default.attributesOfItem(atPath: audioFile.path)[.size] as? Int) ?? 0)
            return CaptureInfo(id: id, directoryURL: item, date: date, size: size)
        }.sorted { $0.date > $1.date }
    }

    func deleteCapture(_ info: CaptureInfo) {
        try? FileManager.default.removeItem(at: info.directoryURL)
    }
}
