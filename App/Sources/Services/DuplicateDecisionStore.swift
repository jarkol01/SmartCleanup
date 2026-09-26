import Foundation

/// Tracks which photos have already been resolved by the "Usuń duplikaty" flow, in its own
/// file/namespace so it never interferes with AssetDecisionStore (the ML delete flow's store).
enum DuplicateDecisionStore {
    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("handled-duplicate-assets.json")

    private static var cache: Set<String> = {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return ids
    }()

    static func isHandled(_ assetIdentifier: String) -> Bool {
        cache.contains(assetIdentifier)
    }

    static func markHandled(_ assetIdentifiers: some Sequence<String>) {
        cache.formUnion(assetIdentifiers)
        try? JSONEncoder().encode(cache).write(to: fileURL, options: .atomic)
    }

    /// Backs "Skanuj ponownie" — forgets every resolved group so a rescan can resurface them.
    static func reset() {
        cache = []
        try? FileManager.default.removeItem(at: fileURL)
    }
}
