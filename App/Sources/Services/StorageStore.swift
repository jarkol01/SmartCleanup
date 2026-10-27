import Foundation

struct StorageSnapshot: Codable {
    let date: Date
    let totalBytes: Int64
    let freeBytes: Int64
    var usedBytes: Int64 { totalBytes - freeBytes }
}

/// Device storage only: iOS has no public API for the user's iCloud account quota/usage.
enum StorageStore {
    private static let snapshotsKey = "stats.storageSnapshots"

    /// "Important usage" free space counts purgeable data, matching Settings › iPhone Storage.
    static func current() -> StorageSnapshot? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return StorageSnapshot(date: .now, totalBytes: Int64(total), freeBytes: free)
    }

    static var snapshots: [StorageSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: snapshotsKey) else { return [] }
        return (try? JSONDecoder().decode([StorageSnapshot].self, from: data)) ?? []
    }

    /// A ≥ 50 MB change adds a point. Smaller drift moves a trailing "drift" point (never a change point),
    /// so the chart keeps every step and still ends at the current "Wolne" value.
    @discardableResult
    static func recordSnapshot() -> StorageSnapshot? {
        guard let snapshot = current() else { return nil }
        var all = snapshots
        let isSmall = { (a: StorageSnapshot, b: StorageSnapshot) in abs(a.freeBytes - b.freeBytes) < 50_000_000 }
        if all.count >= 2, isSmall(all[all.count - 1], snapshot), isSmall(all[all.count - 2], all[all.count - 1]) {
            all.removeLast()
        }
        all.append(snapshot)
        UserDefaults.standard.set(try? JSONEncoder().encode(all.suffix(500)), forKey: snapshotsKey)
        return snapshot
    }
}
