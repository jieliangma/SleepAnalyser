import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case liveSession = "Live Session"
    case morningReport = "Morning Report"
    case trends = "Trends"
    case profiles = "Profiles"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .liveSession: return "waveform"
        case .morningReport: return "doc.text.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .profiles: return "person.2.fill"
        case .settings: return "gear"
        }
    }
}

struct DashboardView: View {
    @State private var selectedItem: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard: DashboardContentView()
                case .liveSession: LiveSessionView()
                case .morningReport: MorningReportView()
                case .trends: TrendsView()
                case .profiles: ProfileListView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}

struct DashboardContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                SleepScoreGaugeView(score: 82, grade: "B")
                    .padding(.top, AppSpacing.xl)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                    MetricCardView(icon: "clock.fill", title: "Total Sleep", value: "7h 23m", accentColor: AppColors.primary)
                    MetricCardView(icon: "percent", title: "Efficiency", value: "92%", accentColor: AppColors.success)
                    MetricCardView(icon: "moon.zzz.fill", title: "Deep Sleep", value: "18%", accentColor: Color(hex: "6366F1"))
                    MetricCardView(icon: "brain.head.profile", title: "REM", value: "22%", accentColor: Color(hex: "A855F7"))
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Sleep Stages")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    HypnogramChartView(epochs: [])
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }

                Button(action: {}) {
                    Label("Start Sleep Tracking", systemImage: "moon.zzz.fill")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}
