import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, AppSpacing.md)
            statusSection
            Divider().padding(.horizontal, AppSpacing.md)
            actionsSection
        }
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 200)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.primary)
            Text(L10n.appName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if appState.isRecording {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.success).frame(width: 6, height: 6)
                    Text(L10n.recording)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.success)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AppColors.success.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private var statusSection: some View {
        VStack(spacing: AppSpacing.sm) {
            if appState.isRecording {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.currentStage.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.stageColor(appState.currentStage))
                        Text(DurationFormatter.format(appState.elapsedTime))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if appState.currentBreathingRate > 0 {
                            Text(L10n.bpmFormat(String(format: "%.0f", appState.currentBreathingRate)))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Text("\(appState.breathCount) \(L10n.breathCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                miniAmplitudeBar
            } else {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(AppColors.textTertiary)
                    Text(L10n.notTracking)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }

    private var miniAmplitudeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.surfaceLight)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary.opacity(0.7))
                    .frame(width: geo.size.width * min(1, appState.currentAmplitude * 8))
                    .animation(.easeOut(duration: 0.1), value: appState.currentAmplitude)
            }
        }
        .frame(height: 3)
    }

    private var actionsSection: some View {
        VStack(spacing: 2) {
            Button {
                dismissPopover()
                Task {
                    if appState.isRecording { try? await appState.stopSession() }
                    else { try? await appState.startSession() }
                }
            } label: {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.fill" : "play.fill")
                        .frame(width: 16)
                    Text(appState.isRecording ? L10n.stop : L10n.startTrackingShort)
                    Spacer()
                    if !appState.isRecording {
                        Text("⌘S").font(.system(size: 11)).foregroundStyle(AppColors.textTertiary)
                    }
                }
                .font(.system(size: 13))
                .padding(.horizontal, AppSpacing.md).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .onHover { inside in /* hover handled by system */ }

            Divider().padding(.horizontal, AppSpacing.md)

            Button {
                dismissPopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                HStack {
                    Image(systemName: "power").frame(width: 16)
                    Text(L10n.quit)
                    Spacer()
                    Text("⌘Q").font(.system(size: 11)).foregroundStyle(AppColors.textTertiary)
                }
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func dismissPopover() {
        NSApp.keyWindow?.close()
    }
}
