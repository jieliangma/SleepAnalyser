import Foundation

final class TrendAggregator: Sendable {
    func aggregate(sessions: [SleepSession], by periodType: PeriodType) -> [TrendSummary] {
        guard !sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped: [Date: [SleepSession]]

        switch periodType {
        case .daily:
            grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startAt) }
        case .weekly:
            grouped = Dictionary(grouping: sessions) {
                calendar.dateInterval(of: .weekOfYear, for: $0.startAt)?.start ?? $0.startAt
            }
        case .monthly:
            grouped = Dictionary(grouping: sessions) {
                calendar.dateInterval(of: .month, for: $0.startAt)?.start ?? $0.startAt
            }
        }

        return grouped.map { (periodStart, periodSessions) in
            let scores = periodSessions.compactMap { s -> Double? in
                s.state == .stopped ? s.efficiency * 100 : nil
            }
            let avgScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let deepPcts = periodSessions.map(\.deepSleepPercent)
            let remPcts = periodSessions.map(\.remPercent)
            let latencies = periodSessions.map(\.latency)

            let avgDeep = deepPcts.reduce(0, +) / Double(max(deepPcts.count, 1))
            let avgREM = remPcts.reduce(0, +) / Double(max(remPcts.count, 1))
            let avgLatency = latencies.reduce(0, +) / Double(max(latencies.count, 1))

            let bedtimes = periodSessions.map { $0.startAt.timeIntervalSince(Calendar.current.startOfDay(for: $0.startAt)) }
            let meanBedtime = bedtimes.reduce(0, +) / Double(max(bedtimes.count, 1))
            let bedtimeVariance = bedtimes.map { ($0 - meanBedtime) * ($0 - meanBedtime) }.reduce(0, +) / Double(max(bedtimes.count, 1))
            let consistency = max(0, 1.0 - sqrt(bedtimeVariance) / 3600.0)

            let periodEnd: Date
            switch periodType {
            case .daily: periodEnd = calendar.date(byAdding: .day, value: 1, to: periodStart) ?? periodStart
            case .weekly: periodEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: periodStart) ?? periodStart
            case .monthly: periodEnd = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
            }

            return TrendSummary(
                profileId: periodSessions.first?.profileId ?? UUID(),
                periodStart: periodStart,
                periodEnd: periodEnd,
                periodType: periodType,
                avgScore: avgScore,
                avgDeepPercent: avgDeep,
                avgREMPercent: avgREM,
                avgLatency: avgLatency,
                consistencyIndex: consistency
            )
        }.sorted { $0.periodStart < $1.periodStart }
    }
}
