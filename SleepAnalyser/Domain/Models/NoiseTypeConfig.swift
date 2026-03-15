import Foundation

struct NoiseTypeConfig: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String
    var sfSymbol: String
    var soundClipURLs: [URL]

    init(id: UUID = UUID(), name: String, colorHex: String, sfSymbol: String, soundClipURLs: [URL] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.soundClipURLs = soundClipURLs
    }

    static let builtIn: [NoiseTypeConfig] = [
        NoiseTypeConfig(name: "traffic",    colorHex: "EF4444", sfSymbol: "car.fill"),
        NoiseTypeConfig(name: "motorcycle", colorHex: "F97316", sfSymbol: "bicycle"),
        NoiseTypeConfig(name: "wind",       colorHex: "38BDF8", sfSymbol: "wind"),
        NoiseTypeConfig(name: "rain",       colorHex: "06B6D4", sfSymbol: "cloud.rain.fill"),
        NoiseTypeConfig(name: "hvac",       colorHex: "F59E0B", sfSymbol: "fan.fill"),
        NoiseTypeConfig(name: "speech",     colorHex: "A855F7", sfSymbol: "person.wave.2.fill"),
        NoiseTypeConfig(name: "quiet",      colorHex: "22C55E", sfSymbol: "speaker.slash.fill"),
    ]
}
