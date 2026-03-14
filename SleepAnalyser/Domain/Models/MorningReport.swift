import Foundation

struct MorningReport: Identifiable, Sendable {
    let id: UUID
    let sessionId: UUID
    let score: SleepScore
    let totalDuration: TimeInterval
    let sleepDuration: TimeInterval
    let efficiency: Double
    let latency: TimeInterval
    let awakenings: Int
    let stageBreakdown: [SleepStage: TimeInterval]
    let events: [AudioEvent]
    let breathingRateAvg: Double
    let insights: [String]

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        score: SleepScore,
        totalDuration: TimeInterval,
        sleepDuration: TimeInterval,
        efficiency: Double,
        latency: TimeInterval,
        awakenings: Int,
        stageBreakdown: [SleepStage: TimeInterval] = [:],
        events: [AudioEvent] = [],
        breathingRateAvg: Double = 0,
        insights: [String] = []
    ) {
        self.id = id
        self.sessionId = sessionId
        self.score = score
        self.totalDuration = totalDuration
        self.sleepDuration = sleepDuration
        self.efficiency = efficiency
        self.latency = latency
        self.awakenings = awakenings
        self.stageBreakdown = stageBreakdown
        self.events = events
        self.breathingRateAvg = breathingRateAvg
        self.insights = insights
    }
}
