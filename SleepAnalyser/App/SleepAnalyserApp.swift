import SwiftUI

@main
struct SleepAnalyserApp: App {
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 650)
                .environment(languageManager)
                .id(languageManager.effectiveLanguageCode)
        }
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra(L10n.appName, systemImage: "moon.zzz.fill") {
            MenuBarView()
                .environment(languageManager)
                .id(languageManager.effectiveLanguageCode)
        }
        .menuBarExtraStyle(.window)
    }
}
