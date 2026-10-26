import Photos
import UIKit

enum PhotoLibraryService {
    static func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// All image assets in the library, newest first.
    static func fetchAllImageAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    static func randomSample(count: Int) -> [PHAsset] {
        fetchAllImageAssets().shuffled().prefix(count).map { $0 }
    }

    /// Tries the on-device copy first: with network allowed Photos may fetch the iCloud original
    /// even when the local "optimized" copy covers the size (on-device tests: always to 1024px).
    static func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        if let local = await requestImage(for: asset, targetSize: targetSize, allowNetwork: false) {
            return local
        }
        return await requestImage(for: asset, targetSize: targetSize, allowNetwork: true)
    }

    static func requestImage(for asset: PHAsset, targetSize: CGSize, allowNetwork: Bool) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = allowNetwork
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Deletes assets and returns whether the user confirmed the system prompt.
    static func delete(_ assets: [PHAsset]) async -> Bool {
        guard !assets.isEmpty else { return true }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
