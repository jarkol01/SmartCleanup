import Photos
import UIKit

struct VideoItem: Identifiable {
    let asset: PHAsset
    let size: Int64
    let skipReason: String?
    var isCompressionCandidate: Bool { skipReason == nil }
    var id: String { asset.localIdentifier }
    var estimatedSavings: Int64 {
        isCompressionCandidate ? VideoCompressor.estimatedSavings(asset, size: size) : 0
    }
}

enum VideoStage: Equatable {
    case checkingAccess
    case accessDenied
    case loading
    case empty
    case list
    case compressing(index: Int, total: Int, phase: VideoCompressor.Phase)
    case copiesReady(count: Int, savedBytes: Int64)
    case deletingOriginals
    case done(count: Int, savedBytes: Int64)
}

@MainActor
@Observable
final class VideoFlow {
    var stage: VideoStage = .checkingAccess
    var videos: [VideoItem] = []
    var selected: Set<String> = []
    var errorMessage: String?

    private var stopRequested = false
    private var pendingOriginals: [PHAsset] = []
    private var pendingSavedBytes: Int64 = 0

    var candidates: [VideoItem] { videos.filter(\.isCompressionCandidate) }

    func start() async {
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .accessDenied
            return
        }
        stage = .loading
        // PHAssetResource lookups are metadata-only but add up over thousands of videos.
        videos = await Task.detached {
            PhotoLibraryService.fetchAllAssets(of: .video).map { asset in
                let size = PhotoLibraryService.videoFileSize(of: asset)
                return VideoItem(asset: asset, size: size, skipReason: VideoCompressor.skipReason(asset, size: size))
            }
            .sorted { $0.size > $1.size }
        }.value
        selected = selected.intersection(candidates.map(\.id))
        stage = videos.isEmpty ? .empty : .list
    }

    func toggleSelection(_ item: VideoItem) {
        if selected.remove(item.id) == nil { selected.insert(item.id) }
    }

    func toggleSelectAll() {
        selected = selected.count == candidates.count ? [] : Set(candidates.map(\.id))
    }

    func delete(_ item: VideoItem) async {
        guard await PhotoLibraryService.delete([item.asset]) else { return }
        StatsStore.record(deletedCount: 1, bytesFreed: item.size)
        videos.removeAll { $0.id == item.id }
        selected.remove(item.id)
        if videos.isEmpty { stage = .empty }
    }

    func compressSelected() {
        let items = videos.filter { selected.contains($0.id) }
        guard !items.isEmpty else { return }
        // Worst case one original downloaded from iCloud plus an output of similar size.
        let needed = 2 * (items.map(\.size).max() ?? 0)
        let free = (try? URL(fileURLWithPath: NSTemporaryDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? 0
        guard free >= needed else {
            let neededText = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
            errorMessage = String(localized: "Za mało wolnego miejsca. Potrzeba około \(neededText).")
            return
        }
        Task { await runCompression(items) }
    }

    /// Stops after the current video; whatever was already compressed still goes to the delete prompt.
    func stop() {
        stopRequested = true
    }

    private func runCompression(_ items: [VideoItem]) async {
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        stopRequested = false
        var originals: [PHAsset] = []
        var savedBytes: Int64 = 0

        for (index, item) in items.enumerated() {
            if stopRequested { break }
            stage = .compressing(index: index + 1, total: items.count, phase: .compressing(0))
            do {
                let output = try await VideoCompressor.compress(item.asset, originalSize: item.size) { [weak self] phase in
                    Task { @MainActor in
                        guard let self, case .compressing(let i, let total, _) = self.stage, i == index + 1 else { return }
                        self.stage = .compressing(index: i, total: total, phase: phase)
                    }
                }
                CompressedVideoStore.markHandled([output.id])
                originals.append(item.asset)
                savedBytes += item.size - output.size
            } catch VideoCompressor.Failure.notWorthIt {
                CompressedVideoStore.markHandled([item.id])
            } catch {
                // Skip to the next one; the original is untouched and nothing was added.
            }
        }

        pendingOriginals = originals
        pendingSavedBytes = savedBytes
        if originals.isEmpty {
            await finish()
        } else {
            // Pause so the user sees the copies are safely saved before the delete prompt appears.
            Haptics.notification(.success)
            stage = .copiesReady(count: originals.count, savedBytes: savedBytes)
        }
    }

    /// One batch = one system prompt. Declining it leaves both copies, nothing is lost.
    func deleteOriginals() async {
        stage = .deletingOriginals
        let deleted = await PhotoLibraryService.delete(pendingOriginals)
        guard deleted else { return await finish() }
        StatsStore.record(deletedCount: 0, bytesFreed: pendingSavedBytes)
        Haptics.notification(.success)
        let done = VideoStage.done(count: pendingOriginals.count, savedBytes: pendingSavedBytes)
        await finish()
        stage = done
    }

    /// Copies stay next to the originals; the copies-ready screen already said so, so straight back to the list.
    func keepOriginals() async {
        await finish()
    }

    private func finish() async {
        pendingOriginals = []
        pendingSavedBytes = 0
        selected = []
        await start()
    }
}
