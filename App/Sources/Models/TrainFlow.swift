import Photos
import SwiftUI

enum TrainStage: Equatable {
    case requestingAccess
    case accessDenied
    case swiping
    case training
    case done
}

@MainActor
@Observable
final class TrainFlow {
    var stage: TrainStage = .requestingAccess
    var pool: [PHAsset] = []
    var errorMessage: String?
    var lastResult: ClassifierTrainer.TrainingResult?

    func start() async {
        let granted = await PhotoLibraryService.requestAuthorization()
        guard granted else {
            stage = .accessDenied
            return
        }
        pool = PhotoLibraryService.fetchAllImageAssets().shuffled()
        stage = .swiping
    }

    /// Called when the user taps "Zakończ" — no fixed sample size, they decide when they're done.
    func finishSwiping() {
        Task { await train() }
    }

    private func train() async {
        stage = .training
        do {
            lastResult = try await ClassifierTrainer.trainAndSave()
            stage = .done
        } catch {
            errorMessage = "Nie udało się wytrenować modelu: \(error.localizedDescription)"
            stage = .swiping
        }
    }
}
