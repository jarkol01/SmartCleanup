import CreateML
import CoreML
import Foundation

enum ClassifierTrainer {
    enum TrainerError: Error {
        case notEnoughData
    }

    static var savedModelURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeleteClassifier.mlmodel")
    }

    /// Trains on TrainingDataStore's Keep/Delete folders and persists the raw model to disk.
    /// Compilation happens on demand in ClassifierRunner: compileModel's output only lives in a
    /// system temp location the framework can delete at any time, so we never try to relocate it.
    static func trainAndSave() async throws -> URL {
        let (keep, delete) = TrainingDataStore.sampleCounts()
        guard keep >= 3, delete >= 3 else { throw TrainerError.notEnoughData }

        let sourceDir = TrainingDataStore.rootDirectory
        let destination = savedModelURL

        return try await Task.detached(priority: .userInitiated) {
            let dataSource = MLImageClassifier.DataSource.labeledDirectories(at: sourceDir)
            let parameters = MLImageClassifier.ModelParameters(featureExtractor: .scenePrint(revision: 2))
            let classifier = try MLImageClassifier(trainingData: dataSource, parameters: parameters)

            try? FileManager.default.removeItem(at: destination)
            try classifier.write(to: destination)
            return destination
        }.value
    }

    static func hasSavedModel() -> Bool {
        FileManager.default.fileExists(atPath: savedModelURL.path)
    }
}
