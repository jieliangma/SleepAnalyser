import SwiftUI

struct MorningReportView: View {
    @Environment(AppState.self) private var appState
    @State private var report: MorningReport?
    @State private var epochs: [SleepEpoch] = []
    @State private var selectedEvent: AudioEvent?

    var body: some View {
        ScrollView {
            if let report {
                VStack(spacing: AppSpacing.lg) {
                    SleepScoreGaugeView(score: report.score.overall, grade: report.score.grade).padding(.top, AppSpacing.lg)
                    metricsRow(report)
                    stagesSection
                    eventsSection(report)
                    insightsSection(report)
                }
                .padding(AppSpacing.lg)
            } else {
                emptyView
            }
        }
        .background(AppColors.background)
        .task { await loadReport() }
    }

    private func metricsRow(_ r: MorningReport) -> some View {
        HStack(spacing: AppSpacing.md) {
            MetricCardView(icon: "bed.double.fill", title: L10n.bedtime, value: formatTime(r.sessionId))
            MetricCardView(icon: "alarm.fill", title: L10n.wakeTime, value: formatEndTime(r.sessionId))
            MetricCardView(icon: "clock.fill", title: L10n.duration, value: DurationFormatter.format(r.totalDuration))
            MetricCardView(icon: "percent", title: L10n.efficiency, value: String(format: "%.0f%%", r.efficiency * 100))
        }
    }

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.sleepStages).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            if epochs.isEmpty {
                Text(L10n.insightTrackMore).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    .frame(height: 200)
            } else {
                HypnogramChartView(epochs: epochs)
                    .padding(AppSpacing.cardPadding).background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
        }
    }

    private func eventsSection(_ r: MorningReport) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.events).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            if r.events.isEmpty {
                Text(L10n.insightNoAwakenings).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            } else {
                EventTimelineView(events: r.events) { event in
                    if event.hasAudioClip, let url = event.audioClipURL {
                        appState.audioPlayer.toggle(url: url, eventId: event.id)
                    }
                    selectedEvent = event
                }
            }
        }
    }

    private func insightsSection(_ r: MorningReport) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.insights).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            ForEach(r.insights, id: \.self) { insight in
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(AppColors.warning)
                    Text(insight).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "doc.text").font(.system(size: 48)).foregroundStyle(AppColors.textTertiary)
            Text(L10n.insightTrackMore).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 100)
    }

    private func loadReport() async {
        if let r = appState.generateReport() {
            report = r
            epochs = appState.epochHistory
            return
        }
        let sessions = (try? await appState.sessionRepo.getSessions(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), to: Date()
        )) ?? []
        if let latest = sessions.first(where: { $0.state == .stopped }) {
            var s = latest
            s.epochs = (try? await appState.sessionRepo.getEpochs(forSession: latest.id)) ?? []
            s.events = (try? await appState.sessionRepo.getEvents(forSession: latest.id)) ?? []
            await MainActor.run {
                epochs = s.epochs
                report = appState.reportGenerator.generateMorningReport(session: s)
            }
        }
    }

    private func formatTime(_ sessionId: UUID) -> String {
        if let s = appState.activeSession, s.id == sessionId { return s.startAt.sleepTimeFormatted }
        return "—"
    }

    private func formatEndTime(_ sessionId: UUID) -> String {
        if let s = appState.activeSession, let end = s.endAt { return end.sleepTimeFormatted }
        return "—"
    }
}
