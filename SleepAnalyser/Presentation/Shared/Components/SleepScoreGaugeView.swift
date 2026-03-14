import SwiftUI

struct SleepScoreGaugeView: View {
    let score: Double
    let grade: String
    var size: CGFloat = 200

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.surfaceLight, lineWidth: 12).frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(score / 100.0, 1.0))
                .stroke(AppColors.scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 1.0), value: score)
            VStack(spacing: AppSpacing.xs) {
                Text("\(Int(score))").font(AppTypography.scoreDisplay).foregroundStyle(AppColors.textPrimary)
                Text(grade).font(AppTypography.headline).foregroundStyle(AppColors.scoreColor(score))
                Text(L10n.sleepScore).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
