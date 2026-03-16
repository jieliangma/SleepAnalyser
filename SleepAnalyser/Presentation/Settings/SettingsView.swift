import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            settingsTabs
            Divider().foregroundStyle(AppColors.surfaceLight)
            TabContent(selectedTab: selectedTab)
        }
        .background(AppColors.background)
    }

    private var settingsTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            tabButton(L10n.storage, icon: "internaldrive.fill", tag: 0)
            tabButton(L10n.audio, icon: "mic.fill", tag: 1)
            tabButton(L10n.language, icon: "globe", tag: 2)
            tabButton(L10n.privacy, icon: "lock.fill", tag: 3)
            tabButton(L10n.about, icon: "info.circle.fill", tag: 4)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
    }

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: selectedTab == tag ? .semibold : .regular))
                .foregroundStyle(selectedTab == tag ? AppColors.primary : AppColors.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selectedTab == tag ? AppColors.primary.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct TabContent: View {
    let selectedTab: Int

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                switch selectedTab {
                case 0: StorageSection()
                case 1: AudioSection()
                case 2: LanguageSection()
                case 3: PrivacySection()
                case 4: AboutSection()
                default: EmptyView()
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}

private struct StorageSection: View {
    @Environment(AppState.self) private var appState
    @State private var maxSizeGB: Double = Double(StorageSettings.maxSizeBytes) / (1024 * 1024 * 1024)
    @State private var maxDays: Double = Double(StorageSettings.maxRetentionDays)
    @State private var currentUsageBytes: Int64 = 0
    @State private var recordingCount: Int = 0

    var body: some View {
        SettingsCard(title: L10n.storageManagement, icon: "internaldrive.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                usageRow

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.maxStorageSize).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(formatGB(maxSizeGB)).font(AppTypography.caption).foregroundStyle(AppColors.textPrimary)
                    }
                    Slider(value: $maxSizeGB, in: 1...30, step: 1)
                        .tint(AppColors.primary)
                        .onChange(of: maxSizeGB) { _, val in
                            StorageSettings.maxSizeBytes = Int64(val * 1024 * 1024 * 1024)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.maxStorageDays).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(L10n.storageDaysValue(Int(maxDays))).font(AppTypography.caption).foregroundStyle(AppColors.textPrimary)
                    }
                    Slider(value: $maxDays, in: 1...365, step: 1)
                        .tint(AppColors.primary)
                        .onChange(of: maxDays) { _, val in
                            StorageSettings.maxRetentionDays = Int(val)
                        }
                }

                Text(L10n.storageNote)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
        .onAppear { refreshUsage() }
    }

    private var usageRow: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.currentUsage).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text(formatBytes(currentUsageBytes))
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.recordingCount).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text("\(recordingCount)")
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func refreshUsage() {
        let recordings = appState.recordingManager.allRecordings()
        recordingCount = recordings.count
        currentUsageBytes = recordings.reduce(0) { $0 + $1.totalSize }
    }

    private func formatGB(_ gb: Double) -> String {
        gb.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.1f MB", mb)
    }
}

enum StorageSettings {
    private static let maxSizeKey = "storage.maxSizeBytes"
    private static let maxDaysKey = "storage.maxRetentionDays"

    static var maxSizeBytes: Int64 {
        get {
            let val = UserDefaults.standard.integer(forKey: maxSizeKey)
            return val > 0 ? Int64(val) : 10 * 1024 * 1024 * 1024
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: maxSizeKey) }
    }

    static var maxRetentionDays: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: maxDaysKey)
            return val > 0 ? val : 7
        }
        set { UserDefaults.standard.set(newValue, forKey: maxDaysKey) }
    }
}

private struct LanguageSection: View {
    @Bindable private var languageManager = LanguageManager.shared

    var body: some View {
        SettingsCard(title: L10n.languageSelection, icon: "globe") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker(L10n.language, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.nativeDisplayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.languageNote)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

private struct AudioSection: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDeviceUID: String = ""
    @State private var sensitivity: Double = 1.0

    var body: some View {
        SettingsCard(title: L10n.audioInput, icon: "mic.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.sensitivity).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Slider(value: $sensitivity, in: 0.5...2.0)
                        .tint(AppColors.primary)
                }

                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(appState.micPermissionGranted ? AppColors.success : AppColors.error)
                        .frame(width: 8, height: 8)
                    Text(appState.micPermissionGranted ? L10n.signalGood : "No Permission")
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if !appState.micPermissionGranted {
                        Button("Grant Access") {
                            Task { await appState.requestMicPermission() }
                        }
                        .font(AppTypography.caption)
                        .buttonStyle(.borderedProminent).tint(AppColors.primary).controlSize(.small)
                    }
                }
            }
        }
        .onAppear {
            selectedDeviceUID = appState.activeProfile?.preferredInputDeviceUID ?? appState.deviceManager.availableDevices.first?.id ?? ""
        }
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value).font(AppTypography.body).foregroundStyle(AppColors.textPrimary)
        }
    }
}

private struct PrivacySection: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirm = false

    var body: some View {
        SettingsCard(title: L10n.data, icon: "lock.shield.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(AppColors.success)
                    Text(L10n.privacyNote)
                        .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(L10n.deleteAllData, systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.error)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .alert(L10n.deleteAllData, isPresented: $showDeleteConfirm) {
            Button(L10n.deleteAllData, role: .destructive) {
                Task {
                    let sessions = (try? await appState.sessionRepo.getSessions(from: Date.distantPast, to: Date.distantFuture)) ?? []
                    for s in sessions { try? await appState.sessionRepo.deleteSession(id: s.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

private struct AboutSection: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer().frame(height: AppSpacing.xl)
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary)
            Text(L10n.appName).font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
            Text(L10n.version).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            Text(L10n.appDescription)
                .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(title, systemImage: icon)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
            content
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}
