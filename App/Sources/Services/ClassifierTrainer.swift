import CreateML
import CoreML
import Foundation

enum ClassifierTrainer {
    enum TrainerError: Error {
        case notEnoughData
    }

    struct TrainingResult {
        let modelURL: URL
        let trainingAccuracy: Double
        /// nil when CreateML's automatic split didn't produce a usable validation slice (tiny datasets).
        let validationAccuracy: Double?
        /// Only computed when there's enough data per class to hold out a proper test set.
        let testAccuracy: Double?
    }

    /// Below this many samples per class, holding out a test slice would leave training starved.
    private static let minPerClassForTestSplit = 10
    private static let testFraction = 0.1

    static var savedModelURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeleteClassifier.mlmodel")
    }

    /// The TrainingDataStore.dataVersion the saved model was last trained on — lets callers
    /// detect a stale model (new Keep/Delete examples since the last train) without retraining
    /// unconditionally every time.
    private static let trainedDataVersionKey = "trainedModel.dataVersion"
    private static var trainedDataVersion: Int {
        get { UserDefaults.standard.integer(forKey: trainedDataVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: trainedDataVersionKey) }
    }

    static var needsRetrain: Bool {
        hasSavedModel() && trainedDataVersion != TrainingDataStore.dataVersion
    }

    /// Trains on TrainingDataStore's Keep/Delete folders and persists the raw model to disk.
    /// Compilation happens on demand in ClassifierRunner: compileModel's output only lives in a
    /// system temp location the framework can delete at any time, so we never try to relocate it.
    static func trainAndSave() async throws -> TrainingResult {
        let (keep, delete) = TrainingDataStore.sampleCounts()
        guard keep >= 3, delete >= 3 else { throw TrainerError.notEnoughData }

        let destination = savedModelURL
        let dataVersionAtStart = TrainingDataStore.dataVersion

        return try await Task.detached(priority: .userInitiated) {
            let split = try makeHoldoutSplit()
            defer {
                if let split { try? FileManager.default.removeItem(at: split.root) }
            }

            let trainSourceDir = split?.trainDir ?? TrainingDataStore.rootDirectory
            let dataSource = MLImageClassifier.DataSource.labeledDirectories(at: trainSourceDir)
            let parameters = MLImageClassifier.ModelParameters(featureExtractor: .scenePrint(revision: 2))
            let classifier = try MLImageClassifier(trainingData: dataSource, parameters: parameters)

            try? FileManager.default.removeItem(at: destination)
            try classifier.write(to: destination)
            trainedDataVersion = dataVersionAtStart

            let trainingAccuracy = 1 - classifier.trainingMetrics.classificationError
            let validationAccuracy = classifier.validationMetrics.isValid
                ? 1 - classifier.validationMetrics.classificationError
                : nil

            var testAccuracy: Double?
            if let split {
                let testMetrics = classifier.evaluation(on: .labeledDirectories(at: split.testDir))
                if testMetrics.isValid {
                    testAccuracy = 1 - testMetrics.classificationError
                }
            }

            return TrainingResult(
                modelURL: destination,
                trainingAccuracy: trainingAccuracy,
                validationAccuracy: validationAccuracy,
                testAccuracy: testAccuracy
            )
        }.value
    }

    static func hasSavedModel() -> Bool {
        FileManager.default.fileExists(atPath: savedModelURL.path)
    }

    /// Copies ~10% of each class into a held-out test folder so evaluation isn't on data the
    /// model already saw. CreateML's own `validation` split (inside the remaining 90%) still
    /// covers early-stopping/tuning, so this gives a genuine train/validation/test split.
    private static func makeHoldoutSplit() throws -> (root: URL, trainDir: URL, testDir: URL)? {
        let labels: [TrainingDataStore.Label] = [.keep, .delete]
        let filesByLabel = Dictionary(uniqueKeysWithValues: labels.map { ($0, TrainingDataStore.files(for: $0)) })
        guard filesByLabel.values.map(\.count).min() ?? 0 >= minPerClassForTestSplit else { return nil }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let trainDir = root.appendingPathComponent("Train")
        let testDir = root.appendingPathComponent("Test")

        for label in labels {
            let files = filesByLabel[label]!.shuffled()
            let testCount = max(1, Int(Double(files.count) * testFraction))
            let testFiles = Set(files.prefix(testCount))

            let trainLabelDir = trainDir.appendingPathComponent(label.rawValue)
            let testLabelDir = testDir.appendingPathComponent(label.rawValue)
            try FileManager.default.createDirectory(at: trainLabelDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: testLabelDir, withIntermediateDirectories: true)

            for file in files {
                let destinationDir = testFiles.contains(file) ? testLabelDir : trainLabelDir
                try FileManager.default.copyItem(at: file, to: destinationDir.appendingPathComponent(file.lastPathComponent))
            }
        }
        return (root, trainDir, testDir)
    }
}
