import Foundation

final class GenerateTrendReportUseCase: Sendable {
    private let reportGenerator: any ReportGeneratorProtocol
    private let sessionRepo: any SessionRepositoryProtocol

    init(reportGenerator: any ReportGeneratorProtocol,
         sessionRepo: any SessionRepositoryProtocol) {
        self.reportGenerator = reportGenerator
        self.sessionRepo = sessionRepo
    }

    func execute(profileId: UUID, periodType: PeriodType, from: Date, to: Date) async throws -> TrendReport {
        let sessions = try await sessionRepo.getSessions(from: from, to: to)
        let profileSessions = sessions.filter { $0.profileId == profileId }
        return reportGenerator.generateTrendReport(sessions: profileSessions, periodType: periodType)
    }
}
