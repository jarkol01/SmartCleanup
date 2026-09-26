import Photos
import UIKit

/// A cluster of visually-similar photos (typically a burst) — 2 or more assets.
struct DuplicateGroup: Identifiable {
    let id = UUID()
    var assets: [PHAsset]
}

/// Finds near-duplicate photo clusters using dHash (difference hash): downscale to 9x8
/// grayscale and compare adjacent pixel brightness into a 64-bit fingerprint. Cheap (just Core
/// Graphics) and tolerant of the minor recompression/exposure noise between burst shots.
enum DuplicateDetector {
    /// Max Hamming distance (out of 64 bits) for two photos to count as duplicates.
    /// ponytail: hand-picked constant rather than a tuned/learned threshold — good enough for
    /// bursts, raise SettingsStore-backed tuning if false positives/negatives show up in practice.
    private static let hammingThreshold = 10

    /// Near-duplicates are almost always taken seconds apart (bursts). Requiring both time
    /// proximity and hash similarity avoids an O(n²) whole-library comparison.
    private static let timeWindow: TimeInterval = 120

    /// Caps how many (newest) assets get scanned per run — full-image loads for hashing aren't
    /// free. ponytail: hard cap instead of paging UI; rescan periodically for older photos.
    static let maxScanCount = 4000

    private static let hashTargetSize = CGSize(width: 32, height: 32)

    /// Scans assets (should already be sorted/limited by the caller) and returns groups of 2+.
    /// `progress` is called after each asset is hashed.
    static func scan(
        assets: [PHAsset],
        progress: @escaping (Int, Int) -> Void
    ) async -> [DuplicateGroup] {
        let sorted = assets.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }

        var hashes: [UInt64?] = []
        hashes.reserveCapacity(sorted.count)
        for (index, asset) in sorted.enumerated() {
            let image = await PhotoLibraryService.requestImage(for: asset, targetSize: hashTargetSize)
            hashes.append(image.flatMap(dHash))
            progress(index + 1, sorted.count)
        }

        var groups: [DuplicateGroup] = []
        var current: [PHAsset] = []
        var currentHash: UInt64?
        var currentDate: Date?

        func closeGroup() {
            if current.count >= 2 { groups.append(DuplicateGroup(assets: current)) }
            current = []
        }

        for (index, asset) in sorted.enumerated() {
            guard let hash = hashes[index] else {
                closeGroup()
                currentHash = nil
                currentDate = nil
                continue
            }
            let date = asset.creationDate
            let withinTime = currentDate.flatMap { last in
                date.map { $0.timeIntervalSince(last) <= timeWindow }
            } ?? false
            let similar = currentHash.map { hammingDistance($0, hash) <= hammingThreshold } ?? false

            if withinTime, similar {
                current.append(asset)
            } else {
                closeGroup()
                current = [asset]
            }
            currentHash = hash
            currentDate = date
        }
        closeGroup()
        return groups
    }

    /// Which asset in a group defaults to "keep": largest pixel dimensions — a cheap proxy for
    /// quality that PHAsset exposes without loading any pixel data. Ties broken by newest.
    static func defaultKeeper(in assets: [PHAsset]) -> PHAsset? {
        assets.max { a, b in
            let pixelsA = a.pixelWidth * a.pixelHeight
            let pixelsB = b.pixelWidth * b.pixelHeight
            if pixelsA != pixelsB { return pixelsA < pixelsB }
            return (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }
    }

    private static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    private static func dHash(_ image: UIImage) -> UInt64? {
        let width = 9
        let height = 8
        guard let cgImage = image.cgImage else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                hash <<= 1
                if pixels[row * width + col] > pixels[row * width + col + 1] { hash |= 1 }
            }
        }
        return hash
    }
}
