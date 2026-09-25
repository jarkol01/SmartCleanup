import Photos
import SwiftUI

enum DeleteStage: Equatable {
    case checkingModel
    case noModel
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

    func start() async {
        guard ClassifierTrainer.hasSavedModel() else {
            stage = .noModel
            return
        }
        guard await PhotoLibraryService.requestAuthorization() else {
            stage = .noModel
            return
        }
        stage = .classifying(done: 0, total: 0)
        do {
            classified = try await ClassifierRunner.classifyAll { done, total in
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
    }

    func confirmDeletion() {
        Task {
            stage = .deleting
            let toDelete = classified.filter { $0.label == .delete }.map(\.asset)

            // Keep a small labeled thumbnail of every user-confirmed decision so the
            // next training round has more (and corrected) data to learn from.
            for item in classified {
                if let image = await PhotoLibraryService.requestImage(
                    for: item.asset, targetSize: CGSize(width: 160, height: 160)
                ) {
                    TrainingDataStore.save(image, assetIdentifier: item.asset.localIdentifier, as: item.label)
                }
            }

            let success = await PhotoLibraryService.delete(toDelete)
            stage = .done(deletedCount: success ? toDelete.count : 0)
        }
    }
}
