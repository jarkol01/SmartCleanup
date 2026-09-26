import Foundation

/// Tracks which photos the user has already resolved in a "Wykryj rozmycie" batch.
/// Deliberately separate from AssetDecisionStore (the ML delete flow's store) so the two
/// tools don't affect each other's candidate pools — a photo dismissed here as "sharp"
/// should still be eligible for the ML flow, and vice versa.
enum BlurDecisionStore {
    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("handled-blur-assets.json")

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
