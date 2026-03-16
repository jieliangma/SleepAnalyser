import Foundation
import CoreAudio

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let sampleRate: Double
    let channelCount: Int
}

struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    let id: String
    let deviceID: AudioDeviceID
    let name: String
}
