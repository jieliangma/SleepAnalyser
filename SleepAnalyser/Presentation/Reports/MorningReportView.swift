import SwiftUI

struct MorningReportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                SleepScoreGaugeView(score: 85, grade: "B")
                    .padding(.top, AppSpacing.lg)

                HStack(spacing: AppSpacing.md) {
                    MetricCardView(icon: "bed.double.fill", title: "Bedtime", value: "11:30 PM")
                    MetricCardView(icon: "alarm.fill", title: "Wake Time", value: "7:15 AM")
                    MetricCardView(icon: "clock.fill", title: "Duration", value: "7h 45m")
                    MetricCardView(icon: "percent", title: "Efficiency", value: "91%")
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

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Events")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    EventTimelineView(events: [])
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Insights")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    ForEach(["Great sleep duration!", "Deep sleep was above average."], id: \.self) { insight in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(AppColors.warning)
                            Text(insight)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}
