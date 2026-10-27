import Foundation

/// Asset IDs a flow has already resolved, persisted as a JSON set in Documents. One store per
/// flow, so e.g. a photo dismissed as "sharp" stays eligible for the ML delete flow.
final class DecisionStore {
    static let photos = DecisionStore(fileName: "handled-assets.json")
    static let blur = DecisionStore(fileName: "handled-blur-assets.json")
    static let duplicates = DecisionStore(fileName: "handled-duplicate-assets.json")
    /// Our own compressed outputs, plus originals that turned out not worth compressing.
    static let compressedVideos = DecisionStore(fileName: "handled-video-assets.json")

    private let fileURL: URL

    private lazy var cache: Set<String> = {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return ids
    }()

    private init(fileName: String) {
        fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func isHandled(_ assetIdentifier: String) -> Bool {
        cache.contains(assetIdentifier)
    }

    func markHandled(_ assetIdentifiers: some Sequence<String>) {
        cache.formUnion(assetIdentifiers)
        try? JSONEncoder().encode(cache).write(to: fileURL, options: .atomic)
    }

    func reset() {
        cache = []
        try? FileManager.default.removeItem(at: fileURL)
    }
}
