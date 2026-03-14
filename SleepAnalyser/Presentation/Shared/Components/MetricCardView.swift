import SwiftUI

struct MetricCardView: View {
    let icon: String
    let title: String
    let value: String
    var accentColor: Color = AppColors.primary
    var trend: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .font(.system(size: 16))
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                if let trend {
                    Text(trend)
                        .font(AppTypography.caption)
                        .foregroundStyle(trend.hasPrefix("+") ? AppColors.success : AppColors.error)
                }
            }
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}
