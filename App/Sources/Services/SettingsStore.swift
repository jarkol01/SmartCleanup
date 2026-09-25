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

enum SettingsStore {
    /// Shared with @AppStorage in SmartCleanupApp/SettingsView so both read/write the same key.
    static let colorSchemeKey = "settings.colorScheme"

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
}
