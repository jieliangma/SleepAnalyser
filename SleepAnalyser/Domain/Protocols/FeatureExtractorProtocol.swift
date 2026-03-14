import Foundation

protocol FeatureExtractorProtocol: Sendable {
    func extractFeatures(from frame: ProcessedFrame) -> FeatureVector
}
