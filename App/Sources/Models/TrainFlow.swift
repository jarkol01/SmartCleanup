import Photos
import SwiftUI

enum TrainStage: Equatable {
    case requestingAccess
    case accessDenied
    case swiping
    case done
}

@MainActor
@Observable
final class TrainFlow {
    var stage: TrainStage = .requestingAccess
    var pool: [PHAsset] = []

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
    /// Labels are already persisted to TrainingDataStore as each swipe happens; actual training
    /// is deferred to right before the next classification run in DeleteFlow, wherever the new
    /// data ends up being needed first.
    func finishSwiping() {
        stage = .done
    }
}
