import Foundation

final class InsightEngine: Sendable {
    func generateInsights(session: SleepSession, score: SleepScore) -> [String] {
        var insights: [String] = []
        let sleepHours = session.sleepDuration / 3600
        let hoursStr = String(format: "%.1f", sleepHours)

        if sleepHours >= 7 && sleepHours <= 9 {
            insights.append(L10n.insightGoodDuration(hoursStr))
        } else if sleepHours < 6 {
            insights.append(L10n.insightShortSleep(hoursStr))
        } else if sleepHours > 10 {
            insights.append(L10n.insightOversleep)
        }

        if session.deepSleepPercent < 0.13 {
            insights.append(L10n.insightLowDeep)
        } else if session.deepSleepPercent > 0.20 {
            insights.append(L10n.insightGoodDeep)
        }

        if session.remPercent < 0.15 {
            insights.append(L10n.insightLowREM)
        }

        if session.awakeningsCount > 3 {
            insights.append(L10n.insightAwakenings(session.awakeningsCount))
        } else if session.awakeningsCount == 0 {
            insights.append(L10n.insightNoAwakenings)
        }

        let disturbances = session.events.filter { $0.eventType == .disturbance }
        if disturbances.count > 2 {
            let sources = Set(disturbances.compactMap(\.source))
            if sources.contains(.traffic) {
                insights.append(L10n.insightTrafficNoise(disturbances.count))
            } else {
                insights.append(L10n.insightDisturbances(disturbances.count))
            }
        }

        if session.latency > 1800 {
            insights.append(L10n.insightSlowOnset)
        } else if session.latency < 300 {
            insights.append(L10n.insightFastOnset)
        }

        let snoreEvents = session.events.filter { $0.eventType == .snore }
        if snoreEvents.count > 5 {
            insights.append(L10n.insightSnoring(snoreEvents.count))
        }

        return insights
    }

    func generateTrendInsights(sessions: [SleepSession], avgScore: Double) -> [String] {
        var insights: [String] = []
        guard sessions.count >= 2 else {
            insights.append(L10n.insightTrackMore)
            return insights
        }

        let sorted = sessions.sorted { $0.startAt < $1.startAt }
        let halfIdx = sorted.count / 2
        let firstHalf = sorted.prefix(halfIdx)
        let secondHalf = sorted.suffix(from: halfIdx)

        let firstAvgEff = firstHalf.map(\.efficiency).reduce(0, +) / Double(Swift.max(firstHalf.count, 1))
        let secondAvgEff = secondHalf.map(\.efficiency).reduce(0, +) / Double(Swift.max(secondHalf.count, 1))

        if secondAvgEff > firstAvgEff + 0.05 {
            insights.append(L10n.insightImproving)
        } else if secondAvgEff < firstAvgEff - 0.05 {
            insights.append(L10n.insightDeclining)
        } else {
            insights.append(L10n.insightConsistent)
        }

        if avgScore >= 80 {
            insights.append(L10n.insightGoodScore(Int(avgScore)))
        } else if avgScore < 60 {
            insights.append(L10n.insightPoorScore(Int(avgScore)))
        }

        return insights
    }
}
