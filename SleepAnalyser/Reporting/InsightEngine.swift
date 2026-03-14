import Foundation

final class InsightEngine: Sendable {
    func generateInsights(session: SleepSession, score: SleepScore) -> [String] {
        var insights: [String] = []

        let sleepHours = session.sleepDuration / 3600
        if sleepHours >= 7 && sleepHours <= 9 {
            insights.append("Great job! You got \(String(format: "%.1f", sleepHours)) hours of sleep, within the recommended range.")
        } else if sleepHours < 6 {
            insights.append("You only slept \(String(format: "%.1f", sleepHours)) hours. Aim for 7-9 hours for optimal recovery.")
        } else if sleepHours > 10 {
            insights.append("You slept over 10 hours. Oversleeping can indicate poor sleep quality.")
        }

        if session.deepSleepPercent < 0.13 {
            insights.append("Your deep sleep was below average. Try maintaining a consistent bedtime and cool room temperature.")
        } else if session.deepSleepPercent > 0.20 {
            insights.append("Excellent deep sleep tonight! This is important for physical recovery.")
        }

        if session.remPercent < 0.15 {
            insights.append("REM sleep was low. Avoiding alcohol and reducing stress may help improve REM sleep.")
        }

        if session.awakeningsCount > 3 {
            insights.append("You had \(session.awakeningsCount) awakenings. Consider reducing noise and light in your bedroom.")
        } else if session.awakeningsCount == 0 {
            insights.append("No awakenings detected — uninterrupted sleep is excellent for recovery!")
        }

        let disturbances = session.events.filter { $0.eventType == .disturbance }
        if disturbances.count > 2 {
            let sources = Set(disturbances.compactMap(\.source))
            if sources.contains(.traffic) {
                insights.append("Traffic noise disturbed your sleep \(disturbances.count) times. Consider earplugs or a white noise machine.")
            } else {
                insights.append("\(disturbances.count) disturbances were detected during the night.")
            }
        }

        if session.latency > 1800 {
            insights.append("It took over 30 minutes to fall asleep. Going to bed earlier or establishing a wind-down routine may help.")
        } else if session.latency < 300 {
            insights.append("You fell asleep quickly — great sleep onset!")
        }

        let snoreEvents = session.events.filter { $0.eventType == .snore }
        if snoreEvents.count > 5 {
            insights.append("Significant snoring was detected (\(snoreEvents.count) events). If persistent, consider consulting a sleep specialist.")
        }

        return insights
    }

    func generateTrendInsights(sessions: [SleepSession], avgScore: Double) -> [String] {
        var insights: [String] = []
        guard sessions.count >= 2 else {
            insights.append("Track more nights to see trends and patterns.")
            return insights
        }

        let sorted = sessions.sorted { $0.startAt < $1.startAt }
        let halfIdx = sorted.count / 2
        let firstHalf = sorted.prefix(halfIdx)
        let secondHalf = sorted.suffix(from: halfIdx)

        let firstAvgEff = firstHalf.map(\.efficiency).reduce(0, +) / Double(max(firstHalf.count, 1))
        let secondAvgEff = secondHalf.map(\.efficiency).reduce(0, +) / Double(max(secondHalf.count, 1))

        if secondAvgEff > firstAvgEff + 0.05 {
            insights.append("Your sleep efficiency is improving! Keep up the good habits.")
        } else if secondAvgEff < firstAvgEff - 0.05 {
            insights.append("Sleep efficiency has declined recently. Review your bedtime routine.")
        } else {
            insights.append("Sleep efficiency has been consistent this period.")
        }

        if avgScore >= 80 {
            insights.append("Overall sleep quality is good with an average score of \(Int(avgScore)).")
        } else if avgScore < 60 {
            insights.append("Average sleep score of \(Int(avgScore)) suggests room for improvement. Focus on consistency and duration.")
        }

        return insights
    }
}
