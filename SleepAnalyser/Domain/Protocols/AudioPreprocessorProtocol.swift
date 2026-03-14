import Foundation

protocol AudioPreprocessorProtocol: Sendable {
    func process(frame: AudioFrame) -> ProcessedFrame
}
