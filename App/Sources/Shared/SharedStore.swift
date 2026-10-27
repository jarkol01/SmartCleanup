import Foundation
import WidgetKit

// Shared with the widget extension, which reads these through the App Group.

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.jkoldun.smartcleanup") ?? .standard
}

enum StatsStore {
    private static let totalDeletedKey = "stats.totalDeleted"
    private static let totalBytesKey = "stats.totalBytesFreedEstimate"

    static var totalDeleted: Int {
        UserDefaults.shared.integer(forKey: totalDeletedKey)
    }

    static var totalBytesFreedEstimate: Int64 {
        Int64(UserDefaults.shared.double(forKey: totalBytesKey))
    }

    /// For callers that already know real bytes (video deletion: file size; compression: before − after).
    static func record(deletedCount: Int, bytesFreed: Int64) {
        UserDefaults.shared.set(totalDeleted + deletedCount, forKey: totalDeletedKey)
        UserDefaults.shared.set(Double(totalBytesFreedEstimate + bytesFreed), forKey: totalBytesKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Stats written before the App Group existed lived in standard defaults.
    static func migrateToAppGroup() {
        for key in [totalDeletedKey, totalBytesKey] where UserDefaults.shared.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) {
                UserDefaults.shared.set(value, forKey: key)
            }
        }
    }
}

/// Training sample counts mirrored for the widget, which can't read the app's Documents folder.
enum ModelProgress {
    static let minSamplesPerClass = 20
    private static let keepKey = "model.keepSamples"
    private static let deleteKey = "model.deleteSamples"

    static var counts: (keep: Int, delete: Int) {
        (UserDefaults.shared.integer(forKey: keepKey), UserDefaults.shared.integer(forKey: deleteKey))
    }

    static func isReady(keep: Int, delete: Int) -> Bool {
        keep >= minSamplesPerClass && delete >= minSamplesPerClass
    }

    static func update(keep: Int, delete: Int) {
        guard counts != (keep, delete) else { return }
        UserDefaults.shared.set(keep, forKey: keepKey)
        UserDefaults.shared.set(delete, forKey: deleteKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// `smartcleanup://<tool>` links opened from the widget.
enum DeepLink: String {
    case delete, blur, duplicates, videos, train

    var url: URL { URL(string: "smartcleanup://\(rawValue)")! }
}
