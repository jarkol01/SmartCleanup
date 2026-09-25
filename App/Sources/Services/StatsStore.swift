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

    static func recordDeletion(of assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        let bytes = assets.reduce(Int64(0)) { $0 + estimatedBytes(for: $1) }
        UserDefaults.standard.set(totalDeleted + assets.count, forKey: totalDeletedKey)
        UserDefaults.standard.set(Double(totalBytesFreedEstimate + bytes), forKey: totalBytesKey)
    }

    /// No on-device app can read the real file size without downloading the original, which is
    /// too slow to do for every deletion. This approximates HEIC/JPEG compression (~0.25 bytes
    /// per pixel) from the asset's resolution, which PHAsset already exposes for free.
    private static func estimatedBytes(for asset: PHAsset) -> Int64 {
        Int64(asset.pixelWidth) * Int64(asset.pixelHeight) / 4
    }
}
