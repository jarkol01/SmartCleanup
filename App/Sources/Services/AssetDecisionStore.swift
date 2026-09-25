import Foundation

/// Tracks which photos the user has already resolved (kept, deleted, or marked as an
/// exception) in a "Usuń zdjęcia" batch, so future batches only offer fresh candidates
/// instead of re-asking about the same photos every session.
enum AssetDecisionStore {
    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("handled-assets.json")

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
}
