import SwiftUI

struct MenuBarView: View {
    @State private var isRecording = false
    @State private var elapsed: TimeInterval = 0

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(AppColors.primary)
                Text("SleepAnalyser")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }

            if isRecording {
                HStack {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                    Text("Recording")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                    Spacer()
                    Text(DurationFormatter.format(elapsed))
                        .font(AppTypography.metricValue)
                        .foregroundStyle(AppColors.textPrimary)
                }
            } else {
                Text("Not tracking")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Divider()

            Button(action: { isRecording.toggle() }) {
                Label(isRecording ? "Stop" : "Start Tracking",
                      systemImage: isRecording ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? AppColors.error : AppColors.primary)

            Button("Open Dashboard") {}
                .buttonStyle(.bordered)
        }
        .padding(AppSpacing.md)
        .frame(width: 280)
    }
}
