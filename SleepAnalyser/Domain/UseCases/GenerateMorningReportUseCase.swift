import Foundation

final class GenerateMorningReportUseCase: Sendable {
    private let reportGenerator: any ReportGeneratorProtocol
    private let sessionRepo: any SessionRepositoryProtocol

    init(reportGenerator: any ReportGeneratorProtocol,
         sessionRepo: any SessionRepositoryProtocol) {
        self.reportGenerator = reportGenerator
        self.sessionRepo = sessionRepo
    }

    func execute(sessionId: UUID) async throws -> MorningReport {
        guard var session = try await sessionRepo.getSession(id: sessionId) else {
            throw SleepSessionError.sessionNotFound
        }

        let epochs = try await sessionRepo.getEpochs(forSession: sessionId)
        let events = try await sessionRepo.getEvents(forSession: sessionId)
        session.epochs = epochs
        session.events = events

        return reportGenerator.generateMorningReport(session: session)
    }
}
