import SwiftUI

@main
struct SleepAnalyserApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 650)
                .environment(languageManager)
                .environment(appState)
                .id(languageManager.effectiveLanguageCode)
        }
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra(L10n.appName, systemImage: "moon.zzz.fill") {
            MenuBarView()
                .environment(languageManager)
                .environment(appState)
                .id(languageManager.effectiveLanguageCode)
        }
        .menuBarExtraStyle(.window)
    }
}
