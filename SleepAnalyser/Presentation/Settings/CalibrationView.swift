import SwiftUI

struct CalibrationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var step: CalibrationStep = .intro
    @State private var progress: Double = 0
    @State private var noiseLevel: Double = -50
    @State private var calibrationResult: AcousticCalibration?
    @State private var errorMsg: String?

    enum CalibrationStep {
        case intro, recording, analyzing, done, error
    }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            stepIndicator
            Spacer()
            stepContent
            Spacer()
            stepActions
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 480, minHeight: 400, maxHeight: 500)
    }

    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<4) { i in
                Circle()
                    .fill(stepIndex >= i ? AppColors.primary : AppColors.surfaceLight)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .intro: return 0
        case .recording: return 1
        case .analyzing: return 2
        case .done, .error: return 3
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "waveform.badge.mic").font(.system(size: 56)).foregroundStyle(AppColors.primary)
                Text(L10n.calibrateRoom).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Text(L10n.calibrationIntro).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, AppSpacing.lg)
            }
        case .recording:
            VStack(spacing: AppSpacing.md) {
                BreathingWaveView(breathingRate: 0, amplitude: 0.3 + progress * 0.5, isActive: true)
                    .frame(height: 100)
                Text(L10n.calibrationRecording).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                ProgressView(value: progress)
                    .tint(AppColors.primary).frame(width: 250)
                Text(String(format: "%.0f dB", noiseLevel))
                    .font(AppTypography.metricValue).foregroundStyle(AppColors.textSecondary)
                Text(L10n.calibrationKeepQuiet).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        case .analyzing:
            VStack(spacing: AppSpacing.md) {
                ProgressView().controlSize(.large)
                Text(L10n.calibrationAnalyzing).font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            }
        case .done:
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(AppColors.success)
                Text(L10n.calibrationDone).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                if let cal = calibrationResult {
                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Text(L10n.calibrationNoiseFloor).foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f dB", cal.baselineNoiseLevel)).foregroundStyle(AppColors.textPrimary)
                        }
                        HStack {
                            Text(L10n.calibrationGain).foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text(String(format: "%.2fx", cal.micGainFactor)).foregroundStyle(AppColors.textPrimary)
                        }
                    }
                    .font(AppTypography.body).padding(AppSpacing.md)
                    .background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }
                noiseClassification
            }
        case .error:
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 56)).foregroundStyle(AppColors.error)
                Text(errorMsg ?? "Calibration failed").font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var noiseClassification: some View {
        HStack(spacing: AppSpacing.sm) {
            let level = noiseLevel
            let (label, color, icon) = classifyNoise(level)
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(AppTypography.caption).foregroundStyle(color)
        }
    }

    private func classifyNoise(_ db: Double) -> (String, Color, String) {
        if db < -45 { return (L10n.calibrationQuiet, AppColors.success, "checkmark.seal.fill") }
        if db < -30 { return (L10n.calibrationModerate, AppColors.warning, "exclamationmark.triangle.fill") }
        return (L10n.calibrationLoud, AppColors.error, "speaker.wave.3.fill")
    }

    @ViewBuilder
    private var stepActions: some View {
        switch step {
        case .intro:
            Button { startCalibration() } label: {
                Text(L10n.calibrationStart).frame(width: 200)
            }
            .buttonStyle(.borderedProminent).tint(AppColors.primary).controlSize(.large)
        case .recording, .analyzing:
            EmptyView()
        case .done:
            Button { dismiss() } label: {
                Text(L10n.calibrationFinish).frame(width: 200)
            }
            .buttonStyle(.borderedProminent).tint(AppColors.primary).controlSize(.large)
        case .error:
            HStack(spacing: AppSpacing.md) {
                Button(L10n.stop) { dismiss() }.buttonStyle(.bordered)
                Button(L10n.calibrationRetry) { startCalibration() }.buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
        }
    }

    private func startCalibration() {
        step = .recording
        progress = 0
        Task {
            do {
                if !appState.micPermissionGranted { await appState.requestMicPermission() }
                guard appState.micPermissionGranted else { throw AudioCaptureError.permissionDenied }

                try await appState.captureService.startCapture()
                let stream = appState.captureService.audioStream
                let preprocessor = AudioPreprocessor()
                var levels: [Double] = []
                let duration: TimeInterval = 10.0
                let start = Date()

                for await frame in stream {
                    let elapsed = Date().timeIntervalSince(start)
                    let processed = preprocessor.process(frame: frame)
                    levels.append(processed.noiseLevel)
                    await MainActor.run {
                        progress = min(1.0, elapsed / duration)
                        noiseLevel = processed.noiseLevel
                    }
                    if elapsed >= duration { break }
                }
                appState.captureService.stopCapture()

                await MainActor.run { step = .analyzing }

                let avg = levels.isEmpty ? -50.0 : levels.reduce(0, +) / Double(levels.count)
                let gain = max(0.5, min(2.0, -30.0 / avg))
                guard let profileId = appState.activeProfile?.id else { throw SleepSessionError.profileNotFound }

                let cal = AcousticCalibration(profileId: profileId, baselineNoiseLevel: avg, micGainFactor: gain)
                try await appState.profileRepo.saveCalibration(cal)

                await MainActor.run {
                    calibrationResult = cal
                    noiseLevel = avg
                    appState.calibration = cal
                    step = .done
                }
            } catch {
                appState.captureService.stopCapture()
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    step = .error
                }
            }
        }
    }
}
