import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AudioSettingsTab()
                .tabItem { Label("Audio", systemImage: "mic.fill") }
            PrivacySettingsTab()
                .tabItem { Label("Privacy", systemImage: "lock.fill") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .padding(AppSpacing.lg)
    }
}

struct AudioSettingsTab: View {
    @State private var selectedDevice = "Default"
    @State private var sensitivity: Double = 1.0

    var body: some View {
        Form {
            Section("Audio Input") {
                Picker("Microphone", selection: $selectedDevice) {
                    Text("Default Microphone").tag("Default")
                }
                Slider(value: $sensitivity, in: 0.5...2.0) {
                    Text("Sensitivity")
                }
                Button("Calibrate Room") {}
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsTab: View {
    var body: some View {
        Form {
            Section("Data") {
                Text("Audio is processed locally and never leaves your device.")
                    .foregroundStyle(AppColors.textSecondary)
                Button("Export Sleep Data") {}
                Button("Delete All Data", role: .destructive) {}
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primary)
            Text("SleepAnalyser")
                .font(AppTypography.title)
            Text("Version 1.0.0")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            Text("Analyze your sleep through breathing sounds.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
