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

                Text(L10n.languageNote)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AudioSettingsTab: View {
    @State private var selectedDevice = "Default"
    @State private var sensitivity: Double = 1.0

    var body: some View {
        Form {
            Section(L10n.audioInput) {
                Picker(L10n.microphone, selection: $selectedDevice) {
                    Text(L10n.defaultMicrophone).tag("Default")
                }
                Slider(value: $sensitivity, in: 0.5...2.0) { Text(L10n.sensitivity) }
                Button(L10n.calibrateRoom) {}
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsTab: View {
    var body: some View {
        Form {
            Section(L10n.data) {
                Text(L10n.privacyNote).foregroundStyle(AppColors.textSecondary)
                Button(L10n.exportData) {}
                Button(L10n.deleteAllData, role: .destructive) {}
            }
        }
        .formStyle(.grouped)
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
