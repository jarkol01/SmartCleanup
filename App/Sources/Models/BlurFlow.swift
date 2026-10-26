import Photos
import SwiftUI

enum BlurLabel: String {
    case blurry, sharp
}

struct BlurredAsset: Identifiable {
    let asset: PHAsset
    var blurScore: Double
    var label: BlurLabel
    /// True once the user has moved this item away from its threshold-assigned label.
    var isUserOverridden = false
    var id: String { asset.localIdentifier }
}

enum BlurStage: Equatable {
    case checkingAccess
    case accessDenied
    case pickingBatchSize
    case noMorePhotos
    case scoring(done: Int, total: Int)
    case results
    case deleting
    case done(deletedCount: Int, freedBytes: Int64)
}

/// Mirrors DeleteFlow's shape (stages, batching, confirm-delete) but scores photos with
/// BlurDetector instead of running the trained classifier — no training data involved.
@MainActor
@Observable
final class BlurFlow {
    static var blurThreshold: Double { SettingsStore.blurThreshold }

    var stage: BlurStage = .checkingAccess
    var scored: [BlurredAsset] = []
    var errorMessage: String?

    private var unhandledPool: [PHAsset] = []
    private var pendingBatch: [PHAsset] = []

    func start() async {
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .accessDenied
            return
        }
        unhandledPool = PhotoLibraryService.fetchAllImageAssets()
            .filter { !BlurDecisionStore.isHandled($0.localIdentifier) }
        stage = unhandledPool.isEmpty ? .noMorePhotos : .pickingBatchSize
    }

    var unhandledCount: Int { unhandledPool.count }

    func scoreBatch(size: Int) {
        pendingBatch = Array(unhandledPool.prefix(size))
        Task { await runScoring() }
    }

    /// Scores up to `maxConcurrent` photos at once, off the main actor: at 1024px each request is
    /// dominated by decode/iCloud fetch latency, so parallel requests overlap that wait.
    private static let maxConcurrent = 4

    private func runScoring() async {
        stage = .scoring(done: 0, total: 0)
        let batch = pendingBatch
        var results = [BlurredAsset?](repeating: nil, count: batch.count)
        var done = 0
        await withTaskGroup(of: (Int, BlurredAsset?).self) { group in
            var next = 0
            func addNext() {
                guard next < batch.count else { return }
                let index = next
                next += 1
                group.addTask { (index, await Self.score(batch[index])) }
            }
            for _ in 0..<Self.maxConcurrent { addNext() }
            for await (index, item) in group {
                results[index] = item
                done += 1
                stage = .scoring(done: done, total: batch.count)
                addNext()
            }
        }
        scored = results.compactMap { $0 }
        stage = .results
    }

    private nonisolated static func score(_ asset: PHAsset) async -> BlurredAsset? {
        let full = CGSize(width: BlurDetector.analysisSide, height: BlurDetector.analysisSide)
        // Optimized-storage iPhones keep only ~256px locally for photos never opened (measured);
        // scoring that copy beats an iCloud download per photo, at the cost of missing mild blur.
        var image = await PhotoLibraryService.requestImage(for: asset, targetSize: full, allowNetwork: false)
        if image == nil {
            image = await PhotoLibraryService.requestImage(
                for: asset, targetSize: CGSize(width: 256, height: 256), allowNetwork: false
            )
        }
        if image == nil {
            image = await PhotoLibraryService.requestImage(for: asset, targetSize: full)
        }
        guard let image, let score = BlurDetector.blurScore(for: image) else { return nil }
        let label: BlurLabel = score >= SettingsStore.blurThreshold ? .blurry : .sharp
        return BlurredAsset(asset: asset, blurScore: score, label: label)
    }

    func moveAsset(_ item: BlurredAsset, to label: BlurLabel) {
        guard let idx = scored.firstIndex(where: { $0.id == item.id }) else { return }
        scored[idx].label = label
        scored[idx].isUserOverridden = true
    }

    func confirmDeletion() {
        Task {
            stage = .deleting
            let toDelete = scored.filter { $0.label == .blurry }.map(\.asset)
            BlurDecisionStore.markHandled(scored.map(\.id))

            let success = await PhotoLibraryService.delete(toDelete)
            let freed = success ? StatsStore.recordDeletion(of: toDelete) : 0
            stage = .done(deletedCount: success ? toDelete.count : 0, freedBytes: freed)
        }
    }

    /// Resets to batch picking so the "Wróć do menu"/"Przetwórz kolejną partię" screen can loop.
    func reset() {
        Task { await start() }
    }
}
