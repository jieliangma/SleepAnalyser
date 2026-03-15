import Foundation

final class MLAutoRetrainer: @unchecked Sendable {
    private let storageDir: URL
    private let retrainThreshold = 10

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/MLFeedback", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    func addConfirmedSample(noiseType: String, features: [String: Double]) {
        var row = features
        row["label"] = nil
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "noiseType": noiseType,
            "features": features
        ]
        let file = storageDir.appendingPathComponent("confirmed_samples.jsonl")
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

        var csv = "noise_type,spectral_centroid,spectral_rolloff,spectral_flatness,zero_crossing_rate,rms_energy\n"
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let noiseType = obj["noiseType"] as? String,
                  let features = obj["features"] as? [String: Double] else { continue }
            let centroid = features["spectral_centroid"] ?? 0
            let rolloff = features["spectral_rolloff"] ?? 0
            let flatness = features["spectral_flatness"] ?? 0
            let zcr = features["zero_crossing_rate"] ?? 0
            let rms = features["rms_energy"] ?? 0
            csv += "\(noiseType),\(centroid),\(rolloff),\(flatness),\(zcr),\(rms)\n"
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
