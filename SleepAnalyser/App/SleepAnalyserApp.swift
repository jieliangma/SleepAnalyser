import SwiftUI

@main
struct SleepAnalyserApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 650)
        }
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("SleepAnalyser", systemImage: "moon.zzz.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
