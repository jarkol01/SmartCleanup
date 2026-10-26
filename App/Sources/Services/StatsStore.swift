import Foundation
import Photos

enum StatsStore {
    private static let totalDeletedKey = "stats.totalDeleted"
    private static let totalBytesKey = "stats.totalBytesFreedEstimate"

    static var totalDeleted: Int {
        UserDefaults.standard.integer(forKey: totalDeletedKey)
    }

    static var totalBytesFreedEstimate: Int64 {
        Int64(UserDefaults.standard.double(forKey: totalBytesKey))
    }

    /// Returns the bytes freed estimate it recorded.
    @discardableResult
    static func recordDeletion(of assets: [PHAsset]) -> Int64 {
        guard !assets.isEmpty else { return 0 }
        let bytes = assets.reduce(Int64(0)) { $0 + estimatedBytes(for: $1) }
        record(deletedCount: assets.count, bytesFreed: bytes)
        return bytes
    }

    /// For callers that already know real bytes (video deletion: file size; compression: before − after).
    static func record(deletedCount: Int, bytesFreed: Int64) {
        UserDefaults.standard.set(totalDeleted + deletedCount, forKey: totalDeletedKey)
        UserDefaults.standard.set(Double(totalBytesFreedEstimate + bytesFreed), forKey: totalBytesKey)
    }

    /// Videos use the real resource size. Photos approximate HEIC/JPEG compression (~0.25 bytes
    /// per pixel) from resolution — cheap, and close enough for a stats tile.
    private static func estimatedBytes(for asset: PHAsset) -> Int64 {
        if asset.mediaType == .video { return PhotoLibraryService.videoFileSize(of: asset) }
        return Int64(asset.pixelWidth) * Int64(asset.pixelHeight) / 4
    }
}
