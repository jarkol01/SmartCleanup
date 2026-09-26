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

    /// CreateML retrains from scratch every time (no incremental fine-tuning API), recomputing
    /// scenePrint features for every training image — so training time and memory scale with
    /// how much data we hand it, not with how much has actually changed. Capping the per-class
    /// sample size bounds a single training run's cost regardless of how large TrainingDataStore
    /// has grown; nothing is deleted from disk, only a random subset is used per run.
    private static let maxSamplesPerClass = 1000

    static var savedModelURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeleteClassifier.mlmodel")
    }

    /// Total Keep+Delete sample count the saved model was last trained on.
    private static let trainedSampleCountKey = "trainedModel.sampleCount"
    private static var trainedSampleCount: Int {
        get { UserDefaults.standard.integer(forKey: trainedSampleCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: trainedSampleCountKey) }
    }

    /// A full retrain redoes feature extraction over the (capped) training sample regardless of
    /// how little changed, so retraining on every new label wastes time for no real accuracy gain
    /// once the dataset is already large. Require the sample count to grow by at least 20% since
    /// the last train before doing it again.
    private static let retrainGrowthThreshold = 0.2

    /// Whether calling trainAndSave() right now would do anything useful — no model yet, or
    /// enough new labels since the last train (see retrainGrowthThreshold) — regardless of
    /// whether those came from "Ucz model" swiping or from confirming a "Usuń zdjęcia" batch.
    /// This is the single retrain trigger, always checked right before a classification run,
    /// never eagerly.
    static var shouldTrain: Bool {
        guard hasSavedModel() else { return true }
        let (keep, delete) = TrainingDataStore.sampleCounts()
        let total = keep + delete
        let requiredGrowth = max(1, Int((Double(trainedSampleCount) * retrainGrowthThreshold).rounded(.up)))
        return total - trainedSampleCount >= requiredGrowth
    }

    static var hasEnoughTrainingData: Bool {
        let (keep, delete) = TrainingDataStore.sampleCounts()
        return keep >= 3 && delete >= 3
    }

    /// Trains on a capped, randomly sampled subset of TrainingDataStore's Keep/Delete folders and
    /// persists the raw model to disk. Compilation happens on demand in ClassifierRunner:
    /// compileModel's output only lives in a system temp location the framework can delete at any
    /// time, so we never try to relocate it.
    static func trainAndSave() async throws -> TrainingResult {
        guard hasEnoughTrainingData else { throw TrainerError.notEnoughData }

        let destination = savedModelURL
        let (keep, delete) = TrainingDataStore.sampleCounts()
        let sampleCountAtStart = keep + delete

        return try await Task.detached(priority: .userInitiated) {
            let split = try makeTrainingDirectories()
            defer { try? FileManager.default.removeItem(at: split.root) }

            let dataSource = MLImageClassifier.DataSource.labeledDirectories(at: split.trainDir)
            let parameters = MLImageClassifier.ModelParameters(featureExtractor: .scenePrint(revision: 2))
            let classifier = try MLImageClassifier(trainingData: dataSource, parameters: parameters)

            try? FileManager.default.removeItem(at: destination)
            try classifier.write(to: destination)
            trainedSampleCount = sampleCountAtStart

            let trainingAccuracy = 1 - classifier.trainingMetrics.classificationError
            let validationAccuracy = classifier.validationMetrics.isValid
                ? 1 - classifier.validationMetrics.classificationError
                : nil

            var testAccuracy: Double?
            if let testDir = split.testDir {
                let testMetrics = classifier.evaluation(on: .labeledDirectories(at: testDir))
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

    /// Copies a capped, random per-class sample into a temp Train dir (and a Test dir with ~10%
    /// of that same sample, when there's enough per class) so a single training run's cost never
    /// scales with the full history stored in TrainingDataStore.
    private static func makeTrainingDirectories() throws -> (root: URL, trainDir: URL, testDir: URL?) {
        let labels: [TrainingDataStore.Label] = [.keep, .delete]
        let sampledByLabel = Dictionary(uniqueKeysWithValues: labels.map {
            ($0, Array(TrainingDataStore.files(for: $0).shuffled().prefix(maxSamplesPerClass)))
        })

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let trainDir = root.appendingPathComponent("Train")
        let withTestSplit = sampledByLabel.values.map(\.count).min() ?? 0 >= minPerClassForTestSplit
        let testDir = withTestSplit ? root.appendingPathComponent("Test") : nil

        for label in labels {
            let files = sampledByLabel[label]!
            let testCount = withTestSplit ? max(1, Int(Double(files.count) * testFraction)) : 0
            let testFiles = Set(files.prefix(testCount))

            let trainLabelDir = trainDir.appendingPathComponent(label.rawValue)
            try FileManager.default.createDirectory(at: trainLabelDir, withIntermediateDirectories: true)
            let testLabelDir = testDir?.appendingPathComponent(label.rawValue)
            if let testLabelDir {
                try FileManager.default.createDirectory(at: testLabelDir, withIntermediateDirectories: true)
            }

            for file in files {
                let destinationDir = testFiles.contains(file) ? testLabelDir! : trainLabelDir
                try FileManager.default.copyItem(at: file, to: destinationDir.appendingPathComponent(file.lastPathComponent))
            }
        }
        return (root, trainDir, testDir)
    }
}
