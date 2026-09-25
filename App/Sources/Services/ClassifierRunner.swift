import CoreML
import Photos
import UIKit
import Vision

struct ClassifiedAsset: Identifiable {
    let asset: PHAsset
    var label: TrainingDataStore.Label
    var confidence: Double
    /// User-confirmed outlier: not saved as training data, and permanently excluded from
    /// future batches so it never has to be reviewed again.
    var isException = false
    var id: String { asset.localIdentifier }
}

enum ClassifierRunner {
    enum RunnerError: Error {
        case modelUnavailable
    }

    /// VisionFeaturePrint.Scene (revision 2) expects 360x360 input; requesting that size
    /// directly avoids Vision upscaling a smaller thumbnail and losing detail.
    private static let modelInputSide: CGFloat = 360

    /// Classifies the given batch of assets, reporting progress as (done, total) via `onProgress`.
    /// ponytail: sequential requests keep memory bounded; if a batch grows into the thousands,
    /// batch with a small TaskGroup concurrency limit instead.
    static func classifyAll(
        assets: [PHAsset],
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> [ClassifiedAsset] {
        guard FileManager.default.fileExists(atPath: ClassifierTrainer.savedModelURL.path) else {
            throw RunnerError.modelUnavailable
        }
        let compiledURL = try await MLModel.compileModel(at: ClassifierTrainer.savedModelURL)
        let mlModel = try MLModel(contentsOf: compiledURL)
        let visionModel = try VNCoreMLModel(for: mlModel)

        var results: [ClassifiedAsset] = []
        results.reserveCapacity(assets.count)

        for (index, asset) in assets.enumerated() {
            if let image = await PhotoLibraryService.requestImage(
                for: asset, targetSize: CGSize(width: modelInputSide, height: modelInputSide)
            ), let cgImage = image.cgImage, let result = classify(cgImage, with: visionModel) {
                results.append(ClassifiedAsset(asset: asset, label: result.label, confidence: result.confidence))
            }
            onProgress(index + 1, assets.count)
        }
        return results
    }

    private static func classify(
        _ cgImage: CGImage, with model: VNCoreMLModel
    ) -> (label: TrainingDataStore.Label, confidence: Double)? {
        let request = VNCoreMLRequest(model: model)
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let top = (request.results as? [VNClassificationObservation])?.first,
              let label = TrainingDataStore.Label(rawValue: top.identifier) else { return nil }
        return (label, Double(top.confidence))
    }
}
