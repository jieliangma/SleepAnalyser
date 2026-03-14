import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            LanguageSettingsTab().tabItem { Label(L10n.language, systemImage: "globe") }
            AudioSettingsTab().tabItem { Label(L10n.audio, systemImage: "mic.fill") }
            PrivacySettingsTab().tabItem { Label(L10n.privacy, systemImage: "lock.fill") }
            AboutTab().tabItem { Label(L10n.about, systemImage: "info.circle.fill") }
        }
        .padding(AppSpacing.lg)
    }
}

struct LanguageSettingsTab: View {
    @Bindable private var languageManager = LanguageManager.shared

    var body: some View {
        Form {
            Section(L10n.languageSelection) {
                Picker(L10n.language, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.nativeDisplayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                Text(L10n.languageNote).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AudioSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDeviceUID: String = ""
    @State private var sensitivity: Double = 1.0
    @State private var showCalibration = false

    var body: some View {
        Form {
            Section(L10n.audioInput) {
                Picker(L10n.microphone, selection: $selectedDeviceUID) {
                    ForEach(appState.deviceManager.availableDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                    if appState.deviceManager.availableDevices.isEmpty {
                        Text(L10n.defaultMicrophone).tag("")
                    }
                }
                .onChange(of: selectedDeviceUID) { _, newUID in
                    guard !newUID.isEmpty, let profile = appState.activeProfile else { return }
                    Task {
                        try? await appState.captureService.switchDevice(uid: newUID)
                        var updated = profile
                        updated.preferredInputDeviceUID = newUID
                        try? await appState.profileRepo.updateProfile(updated)
                        appState.activeProfile = updated
                    }
                }

                Slider(value: $sensitivity, in: 0.5...2.0) { Text(L10n.sensitivity) }

                HStack {
                    Circle()
                        .fill(appState.micPermissionGranted ? AppColors.success : AppColors.error)
                        .frame(width: 8, height: 8)
                    Text(appState.micPermissionGranted ? L10n.signalGood : "No Permission")
                        .font(AppTypography.caption)
                }

                if !appState.micPermissionGranted {
                    Button("Grant Microphone Access") {
                        Task { await appState.requestMicPermission() }
                    }
                }
            }

            Section(L10n.calibrateRoom) {
                if let cal = appState.calibration {
                    HStack {
                        Text(L10n.calibrationNoiseFloor).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f dB", cal.baselineNoiseLevel)).foregroundStyle(AppColors.textPrimary)
                    }
                    .font(AppTypography.body)
                    HStack {
                        Text(L10n.calibrationGain).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.2fx", cal.micGainFactor)).foregroundStyle(AppColors.textPrimary)
                    }
                    .font(AppTypography.body)
                    HStack {
                        Text(L10n.calibrationLastDate).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(cal.lastCalibratedAt, style: .relative).foregroundStyle(AppColors.textTertiary)
                    }
                    .font(AppTypography.caption)
                } else {
                    Text(L10n.calibrationNone).foregroundStyle(AppColors.textTertiary).font(AppTypography.caption)
                }
                Button(appState.calibration == nil ? L10n.calibrationStart : L10n.calibrationRecalibrate) {
                    showCalibration = true
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedDeviceUID = appState.activeProfile?.preferredInputDeviceUID ?? appState.deviceManager.availableDevices.first?.id ?? ""
            if let profileId = appState.activeProfile?.id {
                Task { appState.calibration = try? await appState.profileRepo.getCalibration(profileId: profileId) }
            }
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView()
        }
    }
}

struct PrivacySettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section(L10n.data) {
                Text(L10n.privacyNote).foregroundStyle(AppColors.textSecondary)
                Button(L10n.deleteAllData, role: .destructive) { showDeleteConfirm = true }
            }
        }
        .formStyle(.grouped)
        .alert(L10n.deleteAllData, isPresented: $showDeleteConfirm) {
            Button(L10n.deleteAllData, role: .destructive) {
                Task {
                    let sessions = (try? await appState.sessionRepo.getSessions(
                        from: Date.distantPast, to: Date.distantFuture
                    )) ?? []
                    for s in sessions { try? await appState.sessionRepo.deleteSession(id: s.id) }
                }
            }
            Button(L10n.stop, role: .cancel) {}
        }
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 48)).foregroundStyle(AppColors.primary)
            Text(L10n.appName).font(AppTypography.title)
            Text(L10n.version).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            Text(L10n.appDescription).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
