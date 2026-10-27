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
    /// User-tunable in Settings — see SettingsStore.duplicateHammingThreshold.
    private static var hammingThreshold: Int { SettingsStore.duplicateHammingThreshold }

    /// Near-duplicates are almost always taken seconds apart (bursts). Requiring both time
    /// proximity and hash similarity avoids an O(n²) whole-library comparison.
    private static let timeWindow: TimeInterval = 120

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

        return groupIndices(
            hashes: hashes, dates: sorted.map(\.creationDate), threshold: hammingThreshold
        ).map { DuplicateGroup(assets: $0.map { sorted[$0] }) }
    }

    /// Groups (2+) of consecutive indices whose neighbours are similar and close in time.
    /// Inputs must be sorted by date; a nil hash breaks the run.
    static func groupIndices(hashes: [UInt64?], dates: [Date?], threshold: Int) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        var currentHash: UInt64?
        var currentDate: Date?

        func closeGroup() {
            if current.count >= 2 { groups.append(current) }
            current = []
        }

        for index in hashes.indices {
            guard let hash = hashes[index] else {
                closeGroup()
                currentHash = nil
                currentDate = nil
                continue
            }
            let date = dates[index]
            let withinTime = currentDate.flatMap { last in
                date.map { $0.timeIntervalSince(last) <= timeWindow }
            } ?? false
            let similar = currentHash.map { hammingDistance($0, hash) <= threshold } ?? false

            if withinTime, similar {
                current.append(index)
            } else {
                closeGroup()
                current = [index]
            }
            currentHash = hash
            currentDate = date
        }
        closeGroup()
        return groups
    }

    /// Sharpest photo by BlurDetector — burst shots share a resolution, so pixel count alone
    /// can't tell them apart. Local copies only; ties (or no local copy) fall back to largest, then newest.
    static func defaultKeeper(in assets: [PHAsset]) async -> PHAsset? {
        let side = CGFloat(BlurDetector.analysisSide)
        let byPixels = assets.sorted { a, b in
            let pixelsA = a.pixelWidth * a.pixelHeight
            let pixelsB = b.pixelWidth * b.pixelHeight
            if pixelsA != pixelsB { return pixelsA > pixelsB }
            return (a.creationDate ?? .distantPast) > (b.creationDate ?? .distantPast)
        }
        var best: (asset: PHAsset, blur: Double)?
        for asset in byPixels {
            let image = await PhotoLibraryService.requestImage(
                for: asset, targetSize: CGSize(width: side, height: side), allowNetwork: false
            )
            let blur = image.flatMap(BlurDetector.blurScore) ?? 1
            if best.map({ blur < $0.blur }) ?? true { best = (asset, blur) }
        }
        return best?.asset
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    static func dHash(_ image: UIImage) -> UInt64? {
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
