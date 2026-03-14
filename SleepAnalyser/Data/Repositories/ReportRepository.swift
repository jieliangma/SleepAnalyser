import Foundation

final class ReportRepository: @unchecked Sendable {
    private var cachedReports: [UUID: MorningReport] = [:]
    private var cachedTrends: [String: TrendSummary] = [:]
    private let lock = NSLock()

    func cacheReport(_ report: MorningReport) {
        lock.lock()
        defer { lock.unlock() }
        cachedReports[report.sessionId] = report
    }

    func getCachedReport(sessionId: UUID) -> MorningReport? {
        lock.lock()
        defer { lock.unlock() }
        return cachedReports[sessionId]
    }

    func cacheTrendSummary(_ summary: TrendSummary, key: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedTrends[key] = summary
    }

    func getCachedTrend(key: String) -> TrendSummary? {
        lock.lock()
        defer { lock.unlock() }
        return cachedTrends[key]
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedReports.removeAll()
        cachedTrends.removeAll()
    }
}
