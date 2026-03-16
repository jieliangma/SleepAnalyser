import Foundation

final class EpochDataExporter: @unchecked Sendable {
    private let storageDir: URL
    private let confidenceThreshold: Double = 0.6
    private let fileHandle: FileHandle?
    private let csvURL: URL

    static let csvHeader = "timestamp,stage,confidence," +
        "mfcc_0,mfcc_1,mfcc_2,mfcc_3,mfcc_4,mfcc_5,mfcc_6,mfcc_7,mfcc_8,mfcc_9,mfcc_10,mfcc_11,mfcc_12," +
        "spectral_centroid,spectral_rolloff,spectral_flatness,zero_crossing_rate,rms_energy," +
        "breathing_periodicity,breath_interval_variability\n"

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("SleepAnalyser/TrainingData", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        csvURL = storageDir.appendingPathComponent("epoch_labels.csv")

        if !FileManager.default.fileExists(atPath: csvURL.path) {
            FileManager.default.createFile(atPath: csvURL.path, contents: Self.csvHeader.data(using: .utf8))
        }
        fileHandle = try? FileHandle(forWritingTo: csvURL)
        fileHandle?.seekToEndOfFile()
    }

    deinit {
        fileHandle?.closeFile()
    }

    func record(features: FeatureVector, stage: String, confidence: Double) {
        guard confidence >= confidenceThreshold else { return }
        let mfccs = (0..<13).map { i -> String in
            i < features.mfccCoefficients.count ? String(format: "%.6f", features.mfccCoefficients[i]) : "0"
        }.joined(separator: ",")
        let ts = ISO8601DateFormatter().string(from: features.timestamp)
        let row = "\(ts),\(stage),\(String(format: "%.4f", confidence))," +
            "\(mfccs)," +
            "\(String(format: "%.6f", features.spectralCentroid))," +
            "\(String(format: "%.6f", features.spectralRolloff))," +
            "\(String(format: "%.6f", features.spectralFlatness))," +
            "\(String(format: "%.6f", features.zeroCrossingRate))," +
            "\(String(format: "%.6f", features.rmsEnergy))," +
            "\(String(format: "%.4f", features.breathingPeriodicity))," +
            "\(String(format: "%.4f", features.breathIntervalVariability))\n"
        if let data = row.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    func exportedEpochCount() -> Int {
        guard let content = try? String(contentsOf: csvURL, encoding: .utf8) else { return 0 }
        return max(0, content.components(separatedBy: "\n").filter { !$0.isEmpty }.count - 1)
    }

    func exportURL() -> URL { csvURL }

    func deleteAll() {
        fileHandle?.truncateFile(atOffset: 0)
        fileHandle?.seek(toFileOffset: 0)
        if let data = Self.csvHeader.data(using: .utf8) { fileHandle?.write(data) }
    }
}
