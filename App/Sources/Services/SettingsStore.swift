import Foundation
import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    /// nil lets SwiftUI fall back to the system setting, same as not applying the modifier at all.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "Systemowy"
        case .light: "Jasny"
        case .dark: "Ciemny"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, pl, en, de, fr, es

    var id: String { rawValue }

    /// nil lets SwiftUI fall back to the system's preferred language order, same as not
    /// applying the .environment(\.locale) override at all.
    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }

    /// Each language's own name for itself — like Apple's own language picker, these are never
    /// translated (an autonym is always shown the same way regardless of the app's language).
    var label: String {
        switch self {
        case .system: "Systemowy"
        case .pl: "Polski"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        }
    }
}

enum SettingsStore {
    /// Shared with @AppStorage in SmartCleanupApp/SettingsView so both read/write the same key.
    static let colorSchemeKey = "settings.colorScheme"
    static let languageKey = "settings.language"

    private static let marginKey = "settings.uncertaintyMarginPercent"
    static let defaultMarginPercent: Double = 25

    /// How many percentage points below 100% confidence still count as "uncertain" —
    /// user-adjustable in Settings, 0...50.
    static var uncertaintyMarginPercent: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: marginKey) as? Double
            return stored ?? defaultMarginPercent
        }
        set { UserDefaults.standard.set(newValue, forKey: marginKey) }
    }

    static var uncertaintyThreshold: Double { 1 - uncertaintyMarginPercent / 100 }

    private static let blurThresholdKey = "settings.blurThresholdPercent"
    static let defaultBlurThresholdPercent: Double = 50

    /// Blur-confidence percent (0...100) at or above which a photo is proposed for deletion —
    /// user-adjustable in Settings, separate from the ML flow's uncertaintyMarginPercent.
    static var blurThresholdPercent: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: blurThresholdKey) as? Double
            return stored ?? defaultBlurThresholdPercent
        }
        set { UserDefaults.standard.set(newValue, forKey: blurThresholdKey) }
    }

    static var blurThreshold: Double { blurThresholdPercent / 100 }
}
