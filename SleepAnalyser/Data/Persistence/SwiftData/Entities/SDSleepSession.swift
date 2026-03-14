import Foundation
import SwiftData

@Model
final class SDSleepSession {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var startAt: Date
    var endAt: Date?
    var stateRawValue: String
    var timezone: String

    @Relationship(deleteRule: .cascade) var epochs: [SDSleepEpoch] = []
    @Relationship(deleteRule: .cascade) var events: [SDAudioEvent] = []

    init(id: UUID = UUID(), profileId: UUID, startAt: Date = Date(), endAt: Date? = nil,
         stateRawValue: String = "idle", timezone: String = TimeZone.current.identifier) {
        self.id = id
        self.profileId = profileId
        self.startAt = startAt
        self.endAt = endAt
        self.stateRawValue = stateRawValue
        self.timezone = timezone
    }
}
