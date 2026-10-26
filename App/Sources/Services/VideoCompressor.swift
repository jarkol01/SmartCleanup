import AVFoundation
import Photos

/// Re-encodes one video to HEVC 1080p and saves it as a NEW asset next to the original.
/// Never deletes anything — VideoFlow batches the original deletions into one system prompt.
enum VideoCompressor {
    enum Phase: Equatable {
        case downloading(Double)
        case compressing(Double)
    }

    enum Failure: Error {
        case unavailable, unsupported, notWorthIt, exportFailed, verificationFailed
    }

    /// Rough HEVC 1080p output bitrate; only used to show estimated savings up front.
    private static let estimatedOutputBitsPerSecond: Double = 8_000_000

    /// Localization key explaining why a video isn't offered for compression; nil = candidate.
    /// 12 Mb/s: iPhone 1080p HEVC records at ~8–10, so anything near that gains too little.
    static func skipReason(_ asset: PHAsset, size: Int64) -> String? {
        let subtypes = asset.mediaSubtypes
        if CompressedVideoStore.isHandled(asset.localIdentifier) { return "Już skompresowane" }
        if subtypes.contains(.videoHighFrameRate) { return "Slow motion – pomijane" }
        if subtypes.contains(.videoCinematic) { return "Tryb kinowy – pomijane" }
        let bitsPerSecond = Double(size) * 8 / max(asset.duration, 1)
        if bitsPerSecond < 12_000_000, max(asset.pixelWidth, asset.pixelHeight) <= 1920 {
            return "Już oszczędnie zapisane"
        }
        return nil
    }

    static func estimatedSavings(_ asset: PHAsset, size: Int64) -> Int64 {
        max(0, size - Int64(asset.duration * estimatedOutputBitsPerSecond / 8))
    }

    /// Returns the new asset's localIdentifier and the compressed size. Throws `.notWorthIt` when the
    /// output isn't < 80% of the original; any throw means nothing was added to the library.
    static func compress(
        _ asset: PHAsset,
        originalSize: Int64,
        onPhase: @escaping @Sendable (Phase) -> Void
    ) async throws -> (id: String, size: Int64) {
        let source = try await requestAVAsset(for: asset, onPhase: onPhase)
        // HDR / Dolby Vision would lose its look when squeezed through the SDR-agnostic preset.
        guard try await source.loadTracks(withMediaCharacteristic: .containsHDRVideo).isEmpty,
              let session = AVAssetExportSession(asset: source, presetName: AVAssetExportPresetHEVC1920x1080)
        else { throw Failure.unsupported }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: url) } // no-op once shouldMoveFile took it
        session.outputURL = url
        session.outputFileType = .mov
        session.metadata = try await source.load(.metadata)

        onPhase(.compressing(0))
        let poll = Task {
            while !Task.isCancelled {
                onPhase(.compressing(Double(session.progress)))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        await session.export()
        poll.cancel()
        guard session.status == .completed else { throw session.error ?? Failure.exportFailed }

        let newSize = try await verify(url, against: source, originalSize: originalSize)
        let id = try await saveCopy(of: asset, from: url)
        return (id, newSize)
    }

    private static func requestAVAsset(for asset: PHAsset, onPhase: @escaping @Sendable (Phase) -> Void) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .highQualityFormat
        // Only fires when the original has to come down from iCloud.
        options.progressHandler = { progress, _, _, _ in onPhase(.downloading(progress)) }
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: info?[PHImageErrorKey] as? Error ?? Failure.unavailable)
                }
            }
        }
    }

    private static func verify(_ url: URL, against source: AVAsset, originalSize: Int64) async throws -> Int64 {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
        else { throw Failure.verificationFailed }
        guard Double(size) < 0.8 * Double(originalSize) else { throw Failure.notWorthIt }
        let (duration, isPlayable) = try await AVURLAsset(url: url).load(.duration, .isPlayable)
        let sourceDuration = try await source.load(.duration)
        guard isPlayable, abs(duration.seconds - sourceDuration.seconds) < 0.5 else { throw Failure.verificationFailed }
        return size
    }

    private static func saveCopy(of original: PHAsset, from url: URL) async throws -> String {
        let albums = PHAssetCollection.fetchAssetCollectionsContaining(original, with: .album, options: nil)
        var writableAlbums: [PHAssetCollection] = []
        albums.enumerateObjects { album, _, _ in
            if album.canPerform(.addContent) { writableAlbums.append(album) }
        }
        let newID = IDBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            request.addResource(with: .video, fileURL: url, options: options)
            request.creationDate = original.creationDate
            request.location = original.location
            request.isFavorite = original.isFavorite
            request.isHidden = original.isHidden
            guard let placeholder = request.placeholderForCreatedAsset else { return }
            newID.value = placeholder.localIdentifier
            for album in writableAlbums {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
            }
        }
        guard let id = newID.value else { throw Failure.exportFailed }
        return id
    }

    /// performChanges' block can't mutate a captured local var.
    private final class IDBox: @unchecked Sendable { var value: String? }
}

/// Assets that shouldn't be offered for compression again: our own outputs, and originals
/// that turned out not worth compressing. Same JSON-file pattern as BlurDecisionStore.
enum CompressedVideoStore {
    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("handled-video-assets.json")

    private static var cache: Set<String> = {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return ids
    }()

    static func isHandled(_ assetIdentifier: String) -> Bool {
        cache.contains(assetIdentifier)
    }

    static func markHandled(_ assetIdentifiers: some Sequence<String>) {
        cache.formUnion(assetIdentifiers)
        try? JSONEncoder().encode(cache).write(to: fileURL, options: .atomic)
    }
}
