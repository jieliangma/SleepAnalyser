import Foundation

protocol ReportGeneratorProtocol: Sendable {
    func generateMorningReport(session: SleepSession) -> MorningReport
    func generateTrendReport(sessions: [SleepSession], periodType: PeriodType) -> TrendReport
}
