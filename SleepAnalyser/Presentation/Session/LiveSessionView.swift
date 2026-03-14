import SwiftUI

struct LiveSessionView: View {
    @Environment(AppState.self) private var appState
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if appState.isRecording {
                    recordingContent
                } else {
                    idleContent
                }
                actionButton
            }
            .frame(minWidth: 600, minHeight: 550)
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var recordingContent: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: appState.currentStage.sfSymbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.stageColor(appState.currentStage))
                Text(appState.currentStage.displayName)
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(DurationFormatter.format(appState.elapsedTime))
                    .font(AppTypography.metricValue).foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.lg)

            ZStack {
                BreathingWaveView(
                    breathingRate: appState.currentBreathingRate,
                    amplitude: appState.currentAmplitude,
                    isActive: appState.isRecording
                )
                .frame(height: 180)
                .padding(.horizontal, AppSpacing.md)

                BreathingStatsOverlay(
                    breathingRate: appState.currentBreathingRate,
                    breathCount: appState.breathCount,
                    amplitude: appState.currentAmplitude
                )
            }
            .padding(.vertical, AppSpacing.sm)

            noiseLevelBar
                .padding(.horizontal, AppSpacing.lg)

            HStack(spacing: AppSpacing.md) {
                MetricCardView(
                    icon: "lungs.fill", title: L10n.breathing,
                    value: appState.currentBreathingRate > 0 ? L10n.bpmFormat(String(format: "%.1f", appState.currentBreathingRate)) : "—",
                    accentColor: AppColors.primary
                )
                MetricCardView(
                    icon: "ear.fill", title: L10n.noiseLevel,
                    value: String(format: "%.0f dB", appState.currentNoiseLevel),
                    accentColor: noiseLevelColor
                )
                MetricCardView(
                    icon: "number", title: L10n.breathCount,
                    value: "\(appState.breathCount)",
                    accentColor: Color(hex: "A855F7")
                )
            }
            .padding(.horizontal, AppSpacing.lg)

            if !appState.epochHistory.isEmpty {
                HypnogramChartView(epochs: Array(appState.epochHistory.suffix(240)))
                    .padding(AppSpacing.cardPadding).background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()
        }
    }

    private var noiseLevelBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.noiseLevel).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                Spacer()
                Text(noiseQualityLabel).font(AppTypography.caption).foregroundStyle(noiseLevelColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.surfaceLight)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(noiseLevelColor)
                        .frame(width: geo.size.width * noiseLevelFraction)
                        .animation(.easeOut(duration: 0.3), value: noiseLevelFraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var noiseLevelFraction: Double {
        let db = appState.currentNoiseLevel
        let normalized = (db + 60) / 60
        return max(0, min(1, normalized))
    }

    private var noiseLevelColor: Color {
        let db = appState.currentNoiseLevel
        if db < -40 { return AppColors.success }
        if db < -20 { return AppColors.warning }
        return AppColors.error
    }

    private var noiseQualityLabel: String {
        let db = appState.currentNoiseLevel
        if db < -40 { return L10n.calibrationQuiet }
        if db < -20 { return L10n.calibrationModerate }
        return L10n.calibrationLoud
    }

    private var idleContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            BreathingWaveView(breathingRate: 12, amplitude: 0.2, isActive: false)
                .frame(height: 150).padding(.horizontal, AppSpacing.xl)
            Text(L10n.startTrackingShort).font(AppTypography.title).foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                do {
                    if appState.isRecording { try await appState.stopSession() }
                    else { try await appState.startSession() }
                } catch { errorMessage = error.localizedDescription }
            }
        } label: {
            Label(appState.isRecording ? L10n.stopTracking : L10n.startTrackingShort,
                  systemImage: appState.isRecording ? "stop.fill" : "moon.zzz.fill")
                .font(AppTypography.headline).frame(width: 250).padding()
                .background(appState.isRecording ? AppColors.error : AppColors.primary).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain).padding(.vertical, AppSpacing.lg)
    }
}
