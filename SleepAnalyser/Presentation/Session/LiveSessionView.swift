import SwiftUI

struct LiveSessionView: View {
    @Environment(AppState.self) private var appState
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            if appState.isRecording {
                recordingContent
            } else {
                idleContent
            }
            Spacer()
            actionButton
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var recordingContent: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: appState.currentStage.sfSymbolName)
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.stageColor(appState.currentStage))
                    .animation(.easeInOut, value: appState.currentStage)
                Text(appState.currentStage.displayName).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Text(DurationFormatter.format(appState.elapsedTime)).font(AppTypography.scoreDisplay).foregroundStyle(AppColors.textSecondary)
            }
            HStack(spacing: AppSpacing.xl) {
                MetricCardView(
                    icon: "lungs.fill", title: L10n.breathing,
                    value: appState.currentBreathingRate > 0 ? L10n.bpmFormat(String(format: "%.1f", appState.currentBreathingRate)) : "—",
                    accentColor: AppColors.primary
                )
                MetricCardView(
                    icon: "waveform.path", title: L10n.signal,
                    value: appState.micPermissionGranted ? L10n.signalGood : "—",
                    accentColor: AppColors.success
                )
            }
            .padding(.horizontal, AppSpacing.lg)

            if !appState.epochHistory.isEmpty {
                HypnogramChartView(epochs: Array(appState.epochHistory.suffix(240)))
                    .padding(AppSpacing.cardPadding).background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 64)).foregroundStyle(AppColors.primary.opacity(0.5))
            Text(L10n.startTrackingShort).font(AppTypography.title).foregroundStyle(AppColors.textSecondary)
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                do {
                    if appState.isRecording {
                        try await appState.stopSession()
                    } else {
                        try await appState.startSession()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Label(appState.isRecording ? L10n.stopTracking : L10n.startTrackingShort,
                  systemImage: appState.isRecording ? "stop.fill" : "moon.zzz.fill")
                .font(AppTypography.headline).frame(width: 250).padding()
                .background(appState.isRecording ? AppColors.error : AppColors.primary).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain).padding(.bottom, AppSpacing.xl)
    }
}
