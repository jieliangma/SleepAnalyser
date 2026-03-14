import Foundation

final class MorningReportGenerator: Sendable {
    private let scoreCalculator: SleepScoreCalculator
    private let insightEngine: InsightEngine

    init(scoreCalculator: SleepScoreCalculator = SleepScoreCalculator(),
         insightEngine: InsightEngine = InsightEngine()) {
        self.scoreCalculator = scoreCalculator
        self.insightEngine = insightEngine
    }

    func generateMorningReport(session: SleepSession) -> MorningReport {
        let score = scoreCalculator.calculate(session: session)
        let breathingRates = session.epochs.map(\.respirationRate).filter { $0 > 0 }
        let avgBreathing = breathingRates.isEmpty ? 0 : breathingRates.reduce(0, +) / Double(breathingRates.count)
        let insights = insightEngine.generateInsights(session: session, score: score)

        return MorningReport(
            sessionId: session.id,
            score: score,
            totalDuration: session.totalDuration,
            sleepDuration: session.sleepDuration,
            efficiency: session.efficiency,
            latency: session.latency,
            awakenings: session.awakeningsCount,
            stageBreakdown: session.stageBreakdown,
            events: session.events,
            breathingRateAvg: avgBreathing,
            insights: insights
        )
    }

    func generateTrendReport(sessions: [SleepSession], periodType: PeriodType) -> TrendReport {
        guard !sessions.isEmpty else { return TrendReport.empty }

        let scores = sessions.map { scoreCalculator.calculate(session: $0).overall }
        let durations = sessions.map(\.sleepDuration)

        let avgScore = scores.reduce(0, +) / Double(scores.count)
        let avgDuration = durations.reduce(0, +) / Double(durations.count)

        var stageAvgs: [SleepStage: Double] = [:]
        for stage in [SleepStage.awake, .n1, .n2, .n3, .rem] {
            let pcts = sessions.map { s -> Double in
                guard s.sleepDuration > 0 else { return 0 }
                return (s.stageBreakdown[stage] ?? 0) / s.sleepDuration
            }
            stageAvgs[stage] = pcts.reduce(0, +) / Double(max(pcts.count, 1))
        }

        let sortedDates = sessions.sorted { $0.startAt < $1.startAt }
        let insights = insightEngine.generateTrendInsights(sessions: sessions, avgScore: avgScore)

        return TrendReport(
            periodType: periodType,
            periodStart: sortedDates.first?.startAt ?? Date(),
            periodEnd: sortedDates.last?.startAt ?? Date(),
            sessionCount: sessions.count,
            avgScore: avgScore,
            avgDuration: avgDuration,
            bestNightScore: scores.max() ?? 0,
            worstNightScore: scores.min() ?? 0,
            insights: insights,
            stageAverages: stageAvgs
        )
    }
}
