import SwiftUI
import Charts

struct TrendsView: View {
    @State private var selectedPeriod: PeriodType = .weekly

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Picker(L10n.period, selection: $selectedPeriod) {
                    Text(L10n.week).tag(PeriodType.weekly)
                    Text(L10n.month).tag(PeriodType.monthly)
                }
                .pickerStyle(.segmented).frame(width: 200)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.scoreTrend).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    Chart {
                        ForEach(0..<7, id: \.self) { day in
                            LineMark(x: .value(L10n.chartDay, day), y: .value(L10n.chartScore, Double.random(in: 70...95)))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .frame(height: 200).padding(AppSpacing.cardPadding)
                    .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                    MetricCardView(icon: "chart.bar.fill", title: L10n.avgScore, value: "83")
                    MetricCardView(icon: "clock.fill", title: L10n.avgDuration, value: "7h 30m")
                    MetricCardView(icon: "arrow.up.right", title: L10n.trend, value: L10n.improving, accentColor: AppColors.success)
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}
