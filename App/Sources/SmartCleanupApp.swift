import SwiftUI

@main
struct SmartCleanupApp: App {
    @AppStorage(SettingsStore.colorSchemeKey) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(SettingsStore.languageKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme((AppColorScheme(rawValue: colorSchemeRaw) ?? .system).colorScheme)
                .modifier(LocaleOverride(locale: (AppLanguage(rawValue: languageRaw) ?? .system).locale))
        }
    }
}

/// Only applies .environment(\.locale) when the user picked an explicit language — omitting the
/// modifier entirely for "system" instead of passing the device locale keeps normal system
/// language-list fallback behavior (e.g. a device set to French Canadian still resolves to our
/// French strings rather than being pinned to a single exact locale identifier).
private struct LocaleOverride: ViewModifier {
    let locale: Locale?

    func body(content: Content) -> some View {
        if let locale {
            content.environment(\.locale, locale)
        } else {
            content
        }
    }
}
