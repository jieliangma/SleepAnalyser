import Foundation

final class YAMNetEmbeddingEngine: Sendable {
    func embed(melSpectrogram: [[Float]]) -> [Float] {
        guard !melSpectrogram.isEmpty else { return [] }
        return melSpectrogram.flatMap { $0 }
    }
}
