import Foundation

enum SettingsStore {
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
