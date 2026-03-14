import SwiftUI

struct ConfidenceBadgeView: View {
    let level: ConfidenceLevel

    var body: some View {
        Text(level.displayName)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.confidenceColor(level))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AppColors.confidenceColor(level).opacity(0.15))
            .clipShape(Capsule())
    }
}
