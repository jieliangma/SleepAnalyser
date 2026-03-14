import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPeriod: PeriodType = .weekly
    @State private var sessions: [SleepSession] = []
    @State private var trendReport: TrendReport?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Picker(L10n.period, selection: $selectedPeriod) {
                    Text(L10n.week).tag(PeriodType.weekly)
                    Text(L10n.month).tag(PeriodType.monthly)
                }
                .pickerStyle(.segmented).frame(width: 200)
                .onChange(of: selectedPeriod) { _, _ in Task { await loadData() } }

                if let report = trendReport, report.sessionCount > 0 {
                    scoreChart
                    metricsGrid(report)
                } else {
                    emptyView
                }
            }
            .padding(AppSpacing.lg)
        }
        .task { await loadData() }
    }

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.scoreTrend).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            Chart(sessions.filter { $0.state == .stopped }.sorted { $0.startAt < $1.startAt }, id: \.id) { session in
                let score = appState.scoreCalculator.calculate(session: session).overall
                LineMark(x: .value(L10n.chartDay, session.startAt), y: .value(L10n.chartScore, score))
                    .foregroundStyle(AppColors.primary)
                PointMark(x: .value(L10n.chartDay, session.startAt), y: .value(L10n.chartScore, score))
                    .foregroundStyle(AppColors.primaryLight)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200).padding(AppSpacing.cardPadding)
            .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    private func metricsGrid(_ report: TrendReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
            MetricCardView(icon: "chart.bar.fill", title: L10n.avgScore, value: String(format: "%.0f", report.avgScore))
            MetricCardView(icon: "clock.fill", title: L10n.avgDuration, value: DurationFormatter.format(report.avgDuration))
            MetricCardView(icon: "number", title: L10n.trends, value: "\(report.sessionCount)")
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
            Text(L10n.insightTrackMore).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 80)
    }

    private func loadData() async {
        let (from, to) = dateRange()
        let fetched = (try? await appState.sessionRepo.getSessions(from: from, to: to)) ?? []
        var enriched: [SleepSession] = []
        for var s in fetched where s.state == .stopped {
            s.epochs = (try? await appState.sessionRepo.getEpochs(forSession: s.id)) ?? []
            s.events = (try? await appState.sessionRepo.getEvents(forSession: s.id)) ?? []
            enriched.append(s)
        }
        await MainActor.run {
            sessions = enriched
            trendReport = appState.reportGenerator.generateTrendReport(sessions: enriched, periodType: selectedPeriod)
        }
    }

    private func dateRange() -> (Date, Date) {
        let now = Date()
        let cal = Calendar.current
        switch selectedPeriod {
        case .weekly: return (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .monthly: return (cal.date(byAdding: .month, value: -1, to: now) ?? now, now)
        case .daily: return (cal.startOfDay(for: now), now)
        }
    }
}
