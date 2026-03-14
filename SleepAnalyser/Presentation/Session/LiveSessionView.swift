import SwiftUI

struct LiveSessionView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var currentStage: SleepStage = .awake
    @State private var breathingRate: Double = 14.5
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            VStack(spacing: AppSpacing.md) {
                Image(systemName: currentStage.sfSymbolName)
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.stageColor(currentStage))
                    .animation(.easeInOut, value: currentStage)
                Text(currentStage.displayName).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Text(DurationFormatter.format(elapsedTime)).font(AppTypography.scoreDisplay).foregroundStyle(AppColors.textSecondary)
            }
            HStack(spacing: AppSpacing.xl) {
                MetricCardView(icon: "lungs.fill", title: L10n.breathing, value: L10n.bpmFormat(String(format: "%.1f", breathingRate)), accentColor: AppColors.primary)
                MetricCardView(icon: "waveform.path", title: L10n.signal, value: L10n.signalGood, accentColor: AppColors.success)
            }
            .padding(.horizontal, AppSpacing.lg)
            Spacer()
            Button(action: { isRecording.toggle() }) {
                Label(isRecording ? L10n.stopTracking : L10n.startTrackingShort, systemImage: isRecording ? "stop.fill" : "moon.zzz.fill")
                    .font(AppTypography.headline).frame(width: 250).padding()
                    .background(isRecording ? AppColors.error : AppColors.primary).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
            .buttonStyle(.plain).padding(.bottom, AppSpacing.xl)
        }
    }
}
