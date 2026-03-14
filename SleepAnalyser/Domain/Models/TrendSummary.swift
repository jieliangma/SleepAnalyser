import Foundation

enum PeriodType: String, Codable, Sendable {
    case daily
    case weekly
    case monthly
}

struct TrendSummary: Identifiable, Codable, Sendable {
    let id: UUID
    let profileId: UUID
    let periodStart: Date
    let periodEnd: Date
    let periodType: PeriodType
    var avgScore: Double
    var avgDeepPercent: Double
    var avgREMPercent: Double
    var avgLatency: Double
    var consistencyIndex: Double

    init(
        id: UUID = UUID(),
        profileId: UUID,
        periodStart: Date,
        periodEnd: Date,
        periodType: PeriodType,
        avgScore: Double = 0,
        avgDeepPercent: Double = 0,
        avgREMPercent: Double = 0,
        avgLatency: Double = 0,
        consistencyIndex: Double = 0
    ) {
        self.id = id
        self.profileId = profileId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.periodType = periodType
        self.avgScore = avgScore
        self.avgDeepPercent = avgDeepPercent
        self.avgREMPercent = avgREMPercent
        self.avgLatency = avgLatency
        self.consistencyIndex = consistencyIndex
    }
}
