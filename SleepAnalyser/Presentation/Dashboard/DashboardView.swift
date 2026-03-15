import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, liveSession, morningReport, recordings, trends, profiles, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return L10n.dashboard
        case .liveSession: return L10n.liveSession
        case .morningReport: return L10n.morningReport
        case .recordings: return L10n.recordings
        case .trends: return L10n.trends
        case .profiles: return L10n.profiles
        case .settings: return L10n.settings
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .liveSession: return "waveform"
        case .morningReport: return "doc.text.fill"
        case .recordings: return "recordingtape"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .profiles: return "person.2.fill"
        case .settings: return "gear"
        }
    }
}

struct DashboardView: View {
    @State private var selectedItem: SidebarItem = .dashboard
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, maxWidth: 220)
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard: DashboardContentView()
                case .liveSession: LiveSessionView()
                case .morningReport: MorningReportView()
                case .recordings: AudioRecordingsView()
                case .trends: TrendsView()
                case .profiles: ProfileListView()
                case .settings: SettingsView()
                }
            }
            .frame(minWidth: 700, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
    }
}

struct DashboardContentView: View {
    @Environment(AppState.self) private var appState
    @State private var lastReport: MorningReport?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if let report = lastReport {
                    SleepScoreGaugeView(score: report.score.overall, grade: report.score.grade)
                        .padding(.top, AppSpacing.xl)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppSpacing.md) {
                        MetricCardView(icon: "clock.fill", title: L10n.totalSleep, value: DurationFormatter.format(report.sleepDuration), accentColor: AppColors.primary)
                        MetricCardView(icon: "percent", title: L10n.efficiency, value: String(format: "%.0f%%", report.efficiency * 100), accentColor: AppColors.success)
                        MetricCardView(icon: "moon.zzz.fill", title: L10n.deepSleep, value: stagePercent(.n3, report), accentColor: Color(hex: "6366F1"))
                        MetricCardView(icon: "brain.head.profile", title: L10n.remSleep, value: stagePercent(.rem, report), accentColor: Color(hex: "A855F7"))
                    }
                    if !appState.epochHistory.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(L10n.sleepStages).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                            HypnogramChartView(epochs: appState.epochHistory)
                                .padding(AppSpacing.cardPadding).background(AppColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                        }
                    }
                } else {
                    emptyState
                }

                if !appState.isRecording {
                    Button { Task { try? await appState.startSession() } } label: {
                        Label(L10n.startTracking, systemImage: "moon.zzz.fill")
                            .font(AppTypography.headline).frame(maxWidth: .infinity).padding()
                            .background(AppColors.primary).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.lg)
        }
        .task {
            if let session = appState.activeSession, session.state == .stopped {
                lastReport = appState.generateReport()
            } else {
                let sessions = (try? await appState.sessionRepo.getSessions(
                    from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    to: Date()
                )) ?? []
                if let latest = sessions.first, latest.state == .stopped {
                    var s = latest
                    s.epochs = (try? await appState.sessionRepo.getEpochs(forSession: latest.id)) ?? []
                    s.events = (try? await appState.sessionRepo.getEvents(forSession: latest.id)) ?? []
                    lastReport = appState.reportGenerator.generateMorningReport(session: s)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 64)).foregroundStyle(AppColors.primary.opacity(0.5))
            Text(L10n.insightTrackMore).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 100)
    }

    private func stagePercent(_ stage: SleepStage, _ report: MorningReport) -> String {
        guard report.sleepDuration > 0 else { return "0%" }
        let pct = (report.stageBreakdown[stage] ?? 0) / report.sleepDuration * 100
        return String(format: "%.0f%%", pct)
    }
}
