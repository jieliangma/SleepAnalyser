import Foundation

final class SleepFeedbackStore: @unchecked Sendable {
    private let storageDir: URL
    private let correctionsURL: URL
    private let ratingsURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/TrainingData", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        correctionsURL = storageDir.appendingPathComponent("corrections.csv")
        ratingsURL = storageDir.appendingPathComponent("ratings.csv")

        if !FileManager.default.fileExists(atPath: correctionsURL.path) {
            try? "timestamp,stage\n".write(to: correctionsURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: ratingsURL.path) {
            try? "timestamp,rating,session_id\n".write(to: ratingsURL, atomically: true, encoding: .utf8)
        }
    }

    func addAwakeCorrection(at timestamp: Date) {
        let row = "\(ISO8601DateFormatter().string(from: timestamp)),awake\n"
        appendLine(row, to: correctionsURL)
    }

    func addRating(_ rating: Int, sessionId: UUID) {
        let row = "\(ISO8601DateFormatter().string(from: Date())),\(rating),\(sessionId.uuidString)\n"
        appendLine(row, to: ratingsURL)
    }

    func correctionCount() -> Int {
        lineCount(of: correctionsURL) - 1
    }

    func latestRating(for sessionId: UUID) -> Int? {
        guard let content = try? String(contentsOf: ratingsURL, encoding: .utf8) else { return nil }
        let idStr = sessionId.uuidString
        let lines = content.components(separatedBy: "\n").filter { $0.contains(idStr) }
        guard let last = lines.last else { return nil }
        let parts = last.components(separatedBy: ",")
        return parts.count >= 2 ? Int(parts[1]) : nil
    }

    func correctionsExportURL() -> URL { correctionsURL }
    func epochExportURL() -> URL {
        storageDir.appendingPathComponent("epoch_labels.csv")
    }

    private func appendLine(_ line: String, to url: URL) {
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    private func lineCount(of url: URL) -> Int {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }
}
