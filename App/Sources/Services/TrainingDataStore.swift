import Photos
import UIKit

/// Persists small labeled thumbnails on disk so the classifier can be retrained/updated later
/// without re-asking the user to re-label everything.
enum TrainingDataStore {
    enum Label: String {
        case keep = "Keep"
        case delete = "Delete"
    }

    /// 160px JPEGs at ~0.5 quality: a few KB each, thousands of them still stay under a few MB.
    private static let thumbnailSide: CGFloat = 160
    private static let jpegQuality: CGFloat = 0.5

    static var rootDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrainingData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func directory(for label: Label) -> URL {
        let dir = rootDirectory.appendingPathComponent(label.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage, assetIdentifier: String, as label: Label) -> URL? {
        guard let thumbnail = resize(image, maxSide: thumbnailSide),
              let data = thumbnail.jpegData(compressionQuality: jpegQuality) else { return nil }
        let filename = assetIdentifier.replacingOccurrences(of: "/", with: "_") + ".jpg"
        let url = directory(for: label).appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func remove(assetIdentifier: String, label: Label) {
        let filename = assetIdentifier.replacingOccurrences(of: "/", with: "_") + ".jpg"
        try? FileManager.default.removeItem(at: directory(for: label).appendingPathComponent(filename))
    }

    static func sampleCounts() -> (keep: Int, delete: Int) {
        (files(for: .keep).count, files(for: .delete).count)
    }

    static func files(for label: Label) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory(for: label), includingPropertiesForKeys: nil)) ?? []
    }

    private static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage? {
        let scale = maxSide / max(image.size.width, image.size.height)
        guard scale < 1 else { return image }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
