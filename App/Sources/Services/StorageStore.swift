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

    /// Keeps at most one snapshot per calendar day (the latest reading of the day wins).
    @discardableResult
    static func recordSnapshot() -> StorageSnapshot? {
        guard let snapshot = current() else { return nil }
        var all = snapshots
        if let last = all.last, Calendar.current.isDate(last.date, inSameDayAs: snapshot.date) {
            all.removeLast()
        }
        all.append(snapshot)
        // ponytail: unbounded daily array in UserDefaults (~100 B/day); trim if years of history pile up.
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: snapshotsKey)
        return snapshot
    }
}
