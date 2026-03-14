import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "moon.zzz.fill").foregroundStyle(AppColors.primary)
                Text(L10n.appName).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            if appState.isRecording {
                HStack {
                    Circle().fill(AppColors.success).frame(width: 8, height: 8)
                    Text(L10n.recording).font(AppTypography.caption).foregroundStyle(AppColors.success)
                    Spacer()
                    Text(DurationFormatter.format(appState.elapsedTime)).font(AppTypography.metricValue).foregroundStyle(AppColors.textPrimary)
                }
                HStack {
                    Image(systemName: appState.currentStage.sfSymbolName)
                        .foregroundStyle(AppColors.stageColor(appState.currentStage))
                    Text(appState.currentStage.displayName)
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if appState.currentBreathingRate > 0 {
                        Text(L10n.bpmFormat(String(format: "%.0f", appState.currentBreathingRate)))
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }
            } else {
                Text(L10n.notTracking).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
            }
            Divider()
            Button {
                dismissPopover()
                Task {
                    if appState.isRecording {
                        try? await appState.stopSession()
                    } else {
                        try? await appState.startSession()
                    }
                }
            } label: {
                Label(appState.isRecording ? L10n.stop : L10n.startTrackingShort, systemImage: appState.isRecording ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(appState.isRecording ? AppColors.error : AppColors.primary)
            Divider()
            Button(role: .destructive) {
                dismissPopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Label(L10n.quit, systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(AppSpacing.md).frame(width: 280)
    }

    private func dismissPopover() {
        NSApp.keyWindow?.close()
    }
}
