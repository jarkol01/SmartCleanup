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

    /// For callers that already know real bytes (video deletion: file size; compression: before − after).
    static func record(deletedCount: Int, bytesFreed: Int64) {
        UserDefaults.standard.set(totalDeleted + deletedCount, forKey: totalDeletedKey)
        UserDefaults.standard.set(Double(totalBytesFreedEstimate + bytesFreed), forKey: totalBytesKey)
    }

    /// Call before deleting: resources of an already-deleted asset may no longer be readable.
    /// Photos without a readable size fall back to ~0.25 bytes per pixel (typical HEIC/JPEG).
    static func bytes(of assets: [PHAsset]) -> Int64 {
        assets.reduce(0) { total, asset in
            total + (asset.mediaType == .video
                ? PhotoLibraryService.videoFileSize(of: asset)
                : PhotoLibraryService.photoFileSize(of: asset) ?? Int64(asset.pixelWidth) * Int64(asset.pixelHeight) / 4)
        }
    }
}
