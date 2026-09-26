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
    case done(deletedCount: Int)
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

    // ponytail: sequential requests keep memory bounded, same tradeoff ClassifierRunner makes;
    // batch with a small TaskGroup concurrency limit if scoring thousands gets too slow.
    private func runScoring() async {
        stage = .scoring(done: 0, total: 0)
        var results: [BlurredAsset] = []
        results.reserveCapacity(pendingBatch.count)
        for (index, asset) in pendingBatch.enumerated() {
            if let image = await PhotoLibraryService.requestImage(
                for: asset,
                targetSize: CGSize(width: BlurDetector.analysisSide, height: BlurDetector.analysisSide)
            ), let score = BlurDetector.blurScore(for: image) {
                let label: BlurLabel = score >= BlurFlow.blurThreshold ? .blurry : .sharp
                results.append(BlurredAsset(asset: asset, blurScore: score, label: label))
            }
            stage = .scoring(done: index + 1, total: pendingBatch.count)
        }
        scored = results
        stage = .results
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
            if success {
                StatsStore.recordDeletion(of: toDelete)
            }
            stage = .done(deletedCount: success ? toDelete.count : 0)
        }
    }

    /// Resets to batch picking so the "Wróć do menu"/"Przetwórz kolejną partię" screen can loop.
    func reset() {
        Task { await start() }
    }
}
