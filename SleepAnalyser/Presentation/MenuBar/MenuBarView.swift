import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var focusedIndex: Int = 0
    private let actionCount = 2

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
        .onKeyPress(.upArrow) { moveFocus(-1); return .handled }
        .onKeyPress(.downArrow) { moveFocus(1); return .handled }
        .onKeyPress(.return) { executeAction(focusedIndex); return .handled }
    }

    private func moveFocus(_ delta: Int) {
        focusedIndex = (focusedIndex + delta + actionCount) % actionCount
    }

    private func executeAction(_ index: Int) {
        switch index {
        case 0: toggleSession()
        case 1: quitApp()
        default: break
        }
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
                    Image(systemName: "moon.fill").foregroundStyle(AppColors.textTertiary)
                    Text(L10n.notTracking).font(.system(size: 13)).foregroundStyle(AppColors.textSecondary)
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
                RoundedRectangle(cornerRadius: 2).fill(AppColors.surfaceLight)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary.opacity(0.7))
                    .frame(width: geo.size.width * min(1, appState.currentAmplitude * 8))
                    .animation(.easeOut(duration: 0.1), value: appState.currentAmplitude)
            }
        }
        .frame(height: 3)
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: appState.isRecording ? "stop.fill" : "play.fill",
                title: appState.isRecording ? L10n.stop : L10n.startTrackingShort,
                shortcut: "⌘S",
                isFocused: focusedIndex == 0,
                action: toggleSession
            )

            menuRow(
                icon: "power",
                title: L10n.quit,
                shortcut: "⌘Q",
                isFocused: focusedIndex == 1,
                action: quitApp
            )
        }
        .padding(.vertical, 4)
    }

    private func menuRow(icon: String, title: String, shortcut: String, isFocused: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 16)
                Text(title)
                Spacer()
                Text(shortcut).font(.system(size: 11)).foregroundStyle(isFocused ? .white.opacity(0.7) : AppColors.textTertiary)
            }
            .font(.system(size: 13))
            .foregroundStyle(isFocused ? .white : AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md).padding(.vertical, 7)
            .background(isFocused ? AppColors.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                if title == L10n.quit { focusedIndex = 1 }
                else { focusedIndex = 0 }
            }
        }
    }

    private func toggleSession() {
        dismissPopover()
        Task {
            if appState.isRecording { try? await appState.stopSession() }
            else { try? await appState.startSession() }
        }
    }

    private func quitApp() {
        dismissPopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func dismissPopover() {
        NSApp.keyWindow?.close()
    }
}
