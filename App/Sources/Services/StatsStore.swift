import Foundation
import Photos

extension StatsStore {
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
