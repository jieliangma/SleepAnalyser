import Foundation

struct NoiseSegment: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let timestamp: Date
    var endTime: Date
    var noiseType: String
    var confidence: Double
    var energyDB: Double
    var audioClipURL: URL?
    var isConfirmed: Bool
    var userLabel: String?
    var layer: Int

    init(id: UUID = UUID(), sessionId: UUID, timestamp: Date, endTime: Date,
         noiseType: String, confidence: Double = 0.5, energyDB: Double = -50,
         audioClipURL: URL? = nil, isConfirmed: Bool = false, userLabel: String? = nil, layer: Int = 0) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.endTime = endTime
        self.noiseType = noiseType
        self.confidence = confidence
        self.energyDB = energyDB
        self.audioClipURL = audioClipURL
        self.isConfirmed = isConfirmed
        self.userLabel = userLabel
        self.layer = layer
    }

    var duration: TimeInterval { endTime.timeIntervalSince(timestamp) }
    var displayType: String { userLabel ?? noiseType }
}
