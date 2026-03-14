import Foundation

final class SleepScoreCalculator: Sendable {
    private let durationWeight = 0.25
    private let efficiencyWeight = 0.30
    private let stageBalanceWeight = 0.25
    private let disturbanceWeight = 0.20
    private let targetMinHours = 7.0
    private let targetMaxHours = 9.0

    func calculate(session: SleepSession) -> SleepScore {
        let dScore = calculateDurationScore(session.sleepDuration)
        let eScore = calculateEfficiencyScore(session.efficiency)
        let sScore = calculateStageBalanceScore(session)
        let distScore = calculateDisturbanceScore(session)

        let overall = (dScore * durationWeight +
                       eScore * efficiencyWeight +
                       sScore * stageBalanceWeight +
                       distScore * disturbanceWeight)

        return SleepScore(
            overall: max(0, min(100, overall)),
            durationScore: dScore,
            efficiencyScore: eScore,
            stageBalanceScore: sScore,
            disturbanceScore: distScore
        )
    }

    private func calculateDurationScore(_ sleepDuration: TimeInterval) -> Double {
        let hours = sleepDuration / 3600.0
        if hours >= targetMinHours && hours <= targetMaxHours { return 100 }
        if hours < 4 { return 20 }
        if hours > 11 { return 40 }
        if hours < targetMinHours {
            return 20 + (hours - 4) / (targetMinHours - 4) * 80
        }
        return 100 - (hours - targetMaxHours) / (11 - targetMaxHours) * 60
    }

    private func calculateEfficiencyScore(_ efficiency: Double) -> Double {
        if efficiency >= 0.9 { return 100 }
        if efficiency >= 0.85 { return 80 + (efficiency - 0.85) / 0.05 * 20 }
        if efficiency >= 0.75 { return 50 + (efficiency - 0.75) / 0.10 * 30 }
        return max(0, efficiency / 0.75 * 50)
    }

    private func calculateStageBalanceScore(_ session: SleepSession) -> Double {
        let deepPct = session.deepSleepPercent
        let remPct = session.remPercent

        var score = 100.0
        if deepPct < 0.13 { score -= (0.13 - deepPct) / 0.13 * 40 }
        if deepPct > 0.25 { score -= (deepPct - 0.25) / 0.25 * 20 }
        if remPct < 0.20 { score -= (0.20 - remPct) / 0.20 * 40 }
        if remPct > 0.30 { score -= (remPct - 0.30) / 0.30 * 20 }

        return max(0, min(100, score))
    }

    private func calculateDisturbanceScore(_ session: SleepSession) -> Double {
        let awakenings = session.awakeningsCount
        let disruptiveEvents = session.events.filter { $0.eventType.affectsSleepQuality }.count

        var score = 100.0
        score -= Double(awakenings) * 10
        score -= Double(disruptiveEvents) * 5
        return max(0, min(100, score))
    }
}
