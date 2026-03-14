import Foundation

struct TrendReport: Sendable {
    let periodType: PeriodType
    let periodStart: Date
    let periodEnd: Date
    let sessionCount: Int
    let avgScore: Double
    let avgDuration: TimeInterval
    let bestNightScore: Double
    let worstNightScore: Double
    let insights: [String]
    let stageAverages: [SleepStage: Double]

    static let empty = TrendReport(
        periodType: .weekly,
        periodStart: Date(),
        periodEnd: Date(),
        sessionCount: 0,
        avgScore: 0,
        avgDuration: 0,
        bestNightScore: 0,
        worstNightScore: 0,
        insights: [],
        stageAverages: [:]
    )
}
