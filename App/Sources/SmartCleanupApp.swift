import SwiftUI

@main
struct SmartCleanupApp: App {
    @AppStorage(SettingsStore.colorSchemeKey) private var colorSchemeRaw = AppColorScheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme((AppColorScheme(rawValue: colorSchemeRaw) ?? .system).colorScheme)
        }
    }
}
