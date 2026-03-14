import SwiftUI
import Charts

struct TrendsView: View {
    @State private var selectedPeriod: PeriodType = .weekly

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Picker("Period", selection: $selectedPeriod) {
                    Text("Week").tag(PeriodType.weekly)
                    Text("Month").tag(PeriodType.monthly)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Score Trend")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Chart {
                        ForEach(0..<7, id: \.self) { day in
                            LineMark(
                                x: .value("Day", day),
                                y: .value("Score", Double.random(in: 70...95))
                            )
                            .foregroundStyle(AppColors.primary)
                        }
                    }
                    .frame(height: 200)
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                    MetricCardView(icon: "chart.bar.fill", title: "Avg Score", value: "83")
                    MetricCardView(icon: "clock.fill", title: "Avg Duration", value: "7h 30m")
                    MetricCardView(icon: "arrow.up.right", title: "Trend", value: "Improving", accentColor: AppColors.success)
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}
