import Foundation
import CoreML

enum ModelType: String {
    case sleepStageClassifier = "SleepStageClassifier"
    case snoreDetector = "SnoreDetector"
    case noiseContextClassifier = "NoiseContextClassifier"
}

final class CoreMLModelProvider: @unchecked Sendable {
    private var cache: [ModelType: MLModel] = [:]
    private let lock = NSLock()

    func model(for type: ModelType) -> MLModel? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[type] { return cached }

        guard let url = Bundle.main.url(forResource: type.rawValue, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else {
            return nil
        }

        cache[type] = model
        return model
    }

    func isModelAvailable(_ type: ModelType) -> Bool {
        Bundle.main.url(forResource: type.rawValue, withExtension: "mlmodelc") != nil
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
