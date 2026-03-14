import SwiftUI

@main
struct SleepAnalyserApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 960, minHeight: 680)
                .environment(languageManager)
                .environment(appState)
                .id(languageManager.effectiveLanguageCode)
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)

        MenuBarExtra(L10n.appName, systemImage: "moon.zzz.fill") {
            MenuBarView()
                .environment(languageManager)
                .environment(appState)
                .id(languageManager.effectiveLanguageCode)
        }
        .menuBarExtraStyle(.window)
    }
}
