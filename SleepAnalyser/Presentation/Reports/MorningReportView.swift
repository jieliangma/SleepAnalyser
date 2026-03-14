import SwiftUI

struct MorningReportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                SleepScoreGaugeView(score: 85, grade: "B").padding(.top, AppSpacing.lg)
                HStack(spacing: AppSpacing.md) {
                    MetricCardView(icon: "bed.double.fill", title: L10n.bedtime, value: "11:30 PM")
                    MetricCardView(icon: "alarm.fill", title: L10n.wakeTime, value: "7:15 AM")
                    MetricCardView(icon: "clock.fill", title: L10n.duration, value: "7h 45m")
                    MetricCardView(icon: "percent", title: L10n.efficiency, value: "91%")
                }
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.sleepStages).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    HypnogramChartView(epochs: [])
                        .padding(AppSpacing.cardPadding).background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.events).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    EventTimelineView(events: [])
                }
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.insights).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    ForEach([L10n.insightGoodDeep, L10n.insightFastOnset], id: \.self) { insight in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(AppColors.warning)
                            Text(insight).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}
