import Foundation

final class MLAutoRetrainer: @unchecked Sendable {
    private let storageDir: URL
    private let retrainThreshold = 10

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/MLFeedback", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func deleteAllFeedback() {
        try? FileManager.default.removeItem(at: storageDir)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func addConfirmedSample(noiseType: String, features: [String: Double], segmentId: UUID) {
        let file = storageDir.appendingPathComponent("confirmed_samples.jsonl")

        if let content = try? String(contentsOf: file, encoding: .utf8) {
            let idString = segmentId.uuidString
            let alreadyExists = content.components(separatedBy: "\n").contains { line in
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return false }
                return (obj["segmentId"] as? String) == idString
            }
            if alreadyExists { return }
        }

        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "segmentId": segmentId.uuidString,
            "noiseType": noiseType,
            "features": features
        ]
        if let data = try? JSONSerialization.data(withJSONObject: entry),
           var line = String(data: data, encoding: .utf8) {
            line += "\n"
            if FileManager.default.fileExists(atPath: file.path) {
                    if let handle = try? FileHandle(forWritingTo: file),
                       let lineData = line.data(using: .utf8) {
                        handle.seekToEndOfFile()
                        handle.write(lineData)
                        handle.closeFile()
                }
            } else {
                try? line.write(to: file, atomically: true, encoding: .utf8)
            }
        }

        checkAndRetrain()
    }

    func removeConfirmedSample(segmentId: UUID) {
        let file = storageDir.appendingPathComponent("confirmed_samples.jsonl")
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return }
        let idString = segmentId.uuidString
        let filtered = content.components(separatedBy: "\n").filter { line in
            guard !line.isEmpty else { return false }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return true }
            return (obj["segmentId"] as? String) != idString
        }.joined(separator: "\n")
        let output = filtered.isEmpty ? "" : filtered + "\n"
        try? output.write(to: file, atomically: true, encoding: .utf8)
    }

    func confirmedCount() -> Int {
        let file = storageDir.appendingPathComponent("confirmed_samples.jsonl")
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return 0 }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    func pendingSinceLastTrain() -> Int {
        let lastTrainFile = storageDir.appendingPathComponent("last_train_count.txt")
        let lastCount = Int((try? String(contentsOf: lastTrainFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0
        return confirmedCount() - lastCount
    }

    private func checkAndRetrain() {
        let pending = pendingSinceLastTrain()
        guard pending >= retrainThreshold else { return }
        triggerRetrain()
    }

    func triggerRetrain() {
        let csvPath = exportCSV()
        guard let csv = csvPath else { return }

        let scriptPath = Bundle.main.path(forResource: "retrain_noise", ofType: "py")
            ?? findRetrainScript()

        guard let script = scriptPath else {
            NSLog("MLAutoRetrainer: retrain script not found")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script, "--data", csv.path]
        process.currentDirectoryURL = csv.deletingLastPathComponent()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let countFile = storageDir.appendingPathComponent("last_train_count.txt")
                try? "\(confirmedCount())".write(to: countFile, atomically: true, encoding: .utf8)
                NSLog("MLAutoRetrainer: retrain completed successfully")
            }
        } catch {
            NSLog("MLAutoRetrainer: retrain failed: \(error)")
        }
    }

    private func exportCSV() -> URL? {
        let jsonlFile = storageDir.appendingPathComponent("confirmed_samples.jsonl")
        guard let content = try? String(contentsOf: jsonlFile, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let header = "noise_type,sub_bass,bass,low_mid,mid,high_mid,presence,brilliance,rms_energy,zero_crossing_rate,spectral_centroid"
        var csv = header + "\n"
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let noiseType = obj["noiseType"] as? String,
                  let features = obj["features"] as? [String: Double] else { continue }
            let row = [
                noiseType,
                "\(features["sub_bass"] ?? 0)",
                "\(features["bass"] ?? 0)",
                "\(features["low_mid"] ?? 0)",
                "\(features["mid"] ?? 0)",
                "\(features["high_mid"] ?? 0)",
                "\(features["presence"] ?? 0)",
                "\(features["brilliance"] ?? 0)",
                "\(features["rms_energy"] ?? 0)",
                "\(features["zero_crossing_rate"] ?? 0)",
                "\(features["spectral_centroid"] ?? 0)",
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let csvFile = storageDir.appendingPathComponent("training_data.csv")
        try? csv.write(to: csvFile, atomically: true, encoding: .utf8)
        return csvFile
    }

    private func findRetrainScript() -> String? {
        let candidates = [
            Bundle.main.bundlePath + "/../../../MLTraining/train_models.py",
            FileManager.default.currentDirectoryPath + "/MLTraining/train_models.py"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
