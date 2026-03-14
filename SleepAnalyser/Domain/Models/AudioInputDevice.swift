import Foundation

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let sampleRate: Double
    let channelCount: Int
}
