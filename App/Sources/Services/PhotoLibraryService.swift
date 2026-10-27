import AVFoundation
import Photos
import UIKit

enum PhotoLibraryService {
    static func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// All image assets in the library, newest first.
    static func fetchAllImageAssets() -> [PHAsset] {
        fetchAllAssets(of: .image)
    }

    static func fetchAllAssets(of mediaType: PHAssetMediaType) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: mediaType, options: options)
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

    /// Real on-disk size via PHAssetResource's undocumented-but-stable `fileSize` key (no download).
    /// Falls back to duration × a typical iPhone bitrate for the resolution if the key yields nothing.
    static func videoFileSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first { $0.type == .fullSizeVideo } ?? resources.first { $0.type == .video }
        if let size = resource.flatMap(fileSize) { return size }
        let longSide = max(asset.pixelWidth, asset.pixelHeight)
        let bitsPerSecond: Double = longSide >= 3840 ? 45_000_000 : longSide >= 1920 ? 17_000_000 : 8_000_000
        return Int64(asset.duration * bitsPerSecond / 8)
    }

    /// Sum of every resource deleting the photo frees (original, edited render, Live Photo video);
    /// nil when none reports a size.
    static func photoFileSize(of asset: PHAsset) -> Int64? {
        let sizes = PHAssetResource.assetResources(for: asset).compactMap(fileSize)
        return sizes.isEmpty ? nil : sizes.reduce(0, +)
    }

    private static func fileSize(of resource: PHAssetResource) -> Int64? {
        // responds(to:) guard: KVC on a missing key throws an ObjC exception Swift can't catch.
        guard resource.responds(to: NSSelectorFromString("fileSize")),
              let size = resource.value(forKey: "fileSize") as? Int64, size > 0 else { return nil }
        return size
    }

    static func requestPlayerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                continuation.resume(returning: item)
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
