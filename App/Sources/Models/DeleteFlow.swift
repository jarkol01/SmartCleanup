import Photos
import SwiftUI

enum DeleteStage: Equatable {
    case checkingModel
    case noModel
    case pickingBatchSize
    case noMorePhotos
    case classifying(done: Int, total: Int)
    case results
    case deleting
    case done(deletedCount: Int)
}

@MainActor
@Observable
final class DeleteFlow {
    /// Delete predictions below this confidence are surfaced in the "review uncertain" shortcut.
    static let uncertaintyThreshold = 0.75

    var stage: DeleteStage = .checkingModel
    var classified: [ClassifiedAsset] = []
    var errorMessage: String?

    /// Assets not yet resolved in a previous batch — computed once access is granted.
    private var unhandledPool: [PHAsset] = []

    func start() async {
        guard ClassifierTrainer.hasSavedModel() else {
            stage = .noModel
            return
        }
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .noModel
            return
        }
        unhandledPool = PhotoLibraryService.fetchAllImageAssets()
            .filter { !AssetDecisionStore.isHandled($0.localIdentifier) }
        stage = unhandledPool.isEmpty ? .noMorePhotos : .pickingBatchSize
    }

    var unhandledCount: Int { unhandledPool.count }

    func classifyBatch(size: Int) {
        let batch = Array(unhandledPool.prefix(size))
        Task {
            stage = .classifying(done: 0, total: 0)
            do {
                classified = try await ClassifierRunner.classifyAll(assets: batch) { done, total in
                    Task { @MainActor in self.stage = .classifying(done: done, total: total) }
                }
                stage = .results
            } catch {
                errorMessage = "Nie udało się sklasyfikować zdjęć: \(error.localizedDescription)"
                stage = .results
            }
        }
    }

    func moveAsset(_ item: ClassifiedAsset, to label: TrainingDataStore.Label) {
        guard let idx = classified.firstIndex(where: { $0.id == item.id }) else { return }
        classified[idx].label = label
        classified[idx].isException = false
    }

    /// An exception is a user override that stays out of training data and, once resolved,
    /// never comes up for review again — used for photos that don't fit the general pattern.
    func markException(_ item: ClassifiedAsset, as label: TrainingDataStore.Label) {
        guard let idx = classified.firstIndex(where: { $0.id == item.id }) else { return }
        classified[idx].label = label
        classified[idx].isException = true
    }

    func confirmDeletion() {
        Task {
            stage = .deleting
            let toDelete = classified.filter { $0.label == .delete }.map(\.asset)

            // Keep a small labeled thumbnail of every user-confirmed, non-exception decision
            // so the next training round has more (and corrected) data to learn from.
            for item in classified where !item.isException {
                if let image = await PhotoLibraryService.requestImage(
                    for: item.asset, targetSize: CGSize(width: 160, height: 160)
                ) {
                    TrainingDataStore.save(image, assetIdentifier: item.asset.localIdentifier, as: item.label)
                }
            }
            AssetDecisionStore.markHandled(classified.map(\.id))

            let success = await PhotoLibraryService.delete(toDelete)
            stage = .done(deletedCount: success ? toDelete.count : 0)
        }
    }

    /// Resets to batch picking so the "Wróć do menu"/"Przetwórz kolejną partię" screen can loop.
    func reset() {
        Task { await start() }
    }
}
