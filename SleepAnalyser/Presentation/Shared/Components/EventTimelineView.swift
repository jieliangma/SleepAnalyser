import SwiftUI

struct EventTimelineView: View {
    let events: [AudioEvent]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(events) { event in
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: event.eventType.sfSymbolName)
                            .font(.system(size: 14))
                            .foregroundStyle(severityColor(event.severity))
                        Text(event.startAt, style: .time)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func severityColor(_ severity: Double) -> Color {
        switch severity {
        case 0.7...1.0: return AppColors.error
        case 0.4..<0.7: return AppColors.warning
        default: return AppColors.textSecondary
        }
    }
}
