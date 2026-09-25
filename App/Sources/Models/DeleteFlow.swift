import Photos
import SwiftUI

enum DeleteStage: Equatable {
    case checkingModel
    case notEnoughData
    case accessDenied
    case pickingBatchSize
    case noMorePhotos
    case updatingModel
    case modelUpdated
    case classifying(done: Int, total: Int)
    case results
    case deleting
    case done(deletedCount: Int)
}

@MainActor
@Observable
final class DeleteFlow {
    /// Delete predictions below this confidence are surfaced in the "review uncertain" shortcut.
    /// User-adjustable in Settings.
    static var uncertaintyThreshold: Double { SettingsStore.uncertaintyThreshold }

    var stage: DeleteStage = .checkingModel
    var classified: [ClassifiedAsset] = []
    var errorMessage: String?
    /// Set when classifyBatch retrained the model — shown on the standalone .modelUpdated
    /// checkpoint screen, kept separate from the delete-review UI on purpose.
    var lastTrainingResult: ClassifierTrainer.TrainingResult?

    /// Assets not yet resolved in a previous batch — computed once access is granted.
    private var unhandledPool: [PHAsset] = []
    private var pendingBatch: [PHAsset] = []

    func start() async {
        guard ClassifierTrainer.hasEnoughTrainingData else {
            stage = .notEnoughData
            return
        }
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .accessDenied
            return
        }
        unhandledPool = PhotoLibraryService.fetchAllImageAssets()
            .filter { !AssetDecisionStore.isHandled($0.localIdentifier) }
        stage = unhandledPool.isEmpty ? .noMorePhotos : .pickingBatchSize
    }

    var unhandledCount: Int { unhandledPool.count }

    func classifyBatch(size: Int) {
        pendingBatch = Array(unhandledPool.prefix(size))
        lastTrainingResult = nil
        Task {
            // New Keep/Delete examples (from a previous batch, or from "Ucz model") sit unused
            // until we retrain — do that first so every batch is classified with the latest model.
            // This is the one and only place training happens, regardless of where the data came from.
            guard ClassifierTrainer.shouldTrain else {
                await runClassification()
                return
            }
            stage = .updatingModel
            do {
                lastTrainingResult = try await ClassifierTrainer.trainAndSave()
                // Pause here on a dedicated checkpoint screen instead of folding the result into
                // the delete-review UI — proceedAfterModelUpdate() continues once the user has read it.
                stage = .modelUpdated
            } catch {
                errorMessage = "Nie udało się zaktualizować modelu: \(error.localizedDescription)"
                await runClassification()
            }
        }
    }

    func proceedAfterModelUpdate() {
        Task { await runClassification() }
    }

    private func runClassification() async {
        stage = .classifying(done: 0, total: 0)
        do {
            classified = try await ClassifierRunner.classifyAll(assets: pendingBatch) { done, total in
                Task { @MainActor in self.stage = .classifying(done: done, total: total) }
            }
            stage = .results
        } catch {
            errorMessage = "Nie udało się sklasyfikować zdjęć: \(error.localizedDescription)"
            stage = .results
        }
    }

    func moveAsset(_ item: ClassifiedAsset, to label: TrainingDataStore.Label) {
        guard let idx = classified.firstIndex(where: { $0.id == item.id }) else { return }
        classified[idx].label = label
        classified[idx].isException = false
        classified[idx].isUserOverridden = true
    }

    /// An exception is a user override that stays out of training data and, once resolved,
    /// never comes up for review again — used for photos that don't fit the general pattern.
    func markException(_ item: ClassifiedAsset, as label: TrainingDataStore.Label) {
        guard let idx = classified.firstIndex(where: { $0.id == item.id }) else { return }
        classified[idx].label = label
        classified[idx].isUserOverridden = true
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
