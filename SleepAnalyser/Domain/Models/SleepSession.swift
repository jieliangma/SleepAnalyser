import Foundation

struct SleepSession: Identifiable, Codable, Sendable {
    let id: UUID
    let profileId: UUID
    let startAt: Date
    var endAt: Date?
    var state: SessionState
    let timezone: String
    var epochs: [SleepEpoch]
    var events: [AudioEvent]

    init(
        id: UUID = UUID(),
        profileId: UUID,
        startAt: Date = Date(),
        endAt: Date? = nil,
        state: SessionState = .idle,
        timezone: String = TimeZone.current.identifier,
        epochs: [SleepEpoch] = [],
        events: [AudioEvent] = []
    ) {
        self.id = id
        self.profileId = profileId
        self.startAt = startAt
        self.endAt = endAt
        self.state = state
        self.timezone = timezone
        self.epochs = epochs
        self.events = events
    }

    var totalDuration: TimeInterval {
        guard let endAt else { return Date().timeIntervalSince(startAt) }
        return endAt.timeIntervalSince(startAt)
    }

    var sleepDuration: TimeInterval {
        let sleepEpochs = epochs.filter { $0.predictedStage.isAsleep }
        return Double(sleepEpochs.count) * 30.0
    }

    var efficiency: Double {
        guard totalDuration > 0 else { return 0 }
        return sleepDuration / totalDuration
    }

    /// Time in seconds from session start to first non-awake epoch
    var latency: TimeInterval {
        guard let firstSleepEpoch = epochs.first(where: { $0.predictedStage.isAsleep }) else {
            return totalDuration
        }
        return firstSleepEpoch.timestamp.timeIntervalSince(startAt)
    }

    var awakeningsCount: Int {
        var count = 0
        var wasSleeping = false
        for epoch in epochs.sorted(by: { $0.timestamp < $1.timestamp }) {
            if epoch.predictedStage.isAsleep {
                wasSleeping = true
            } else if epoch.predictedStage == .awake && wasSleeping {
                count += 1
                wasSleeping = false
            }
        }
        return count
    }

    var stageBreakdown: [SleepStage: TimeInterval] {
        var breakdown: [SleepStage: TimeInterval] = [:]
        for epoch in epochs {
            breakdown[epoch.predictedStage, default: 0] += 30.0
        }
        return breakdown
    }

    var deepSleepPercent: Double {
        guard sleepDuration > 0 else { return 0 }
        return (stageBreakdown[.n3] ?? 0) / sleepDuration
    }

    var remPercent: Double {
        guard sleepDuration > 0 else { return 0 }
        return (stageBreakdown[.rem] ?? 0) / sleepDuration
    }
}
