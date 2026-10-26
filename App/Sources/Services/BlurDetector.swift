import Accelerate
import CoreGraphics
import UIKit

/// Pure signal-processing blur heuristic — no CoreML/Vision, no training data. See
/// docs/features/blur-detection.md for the algorithm and normalization writeup.
enum BlurDetector {
    /// At 256px a full-res shake blur shrinks below one pixel and vanishes; 1024 keeps it visible.
    /// Smaller sources are analyzed at their own size, since upscaling would fake blur.
    static let analysisSide = 1024

    /// Score uses the sharpest cell of this grid, so a sharp subject on bokeh still reads sharp.
    private static let gridSize = 4

    /// Empirically-picked divisor for the variance→0...1 squashing below; see the doc for how
    /// it was chosen. Not a hard variance cutoff — SettingsStore.blurThreshold is that knob.
    private static let varianceScale: Double = 1500

    /// 0...1 confidence that the image is blurry (mirrors ClassifiedAsset.confidence's shape).
    /// Higher Laplacian variance = sharper edges = lower blur confidence.
    static func blurScore(for cgImage: CGImage) -> Double? {
        let side = min(analysisSide, cgImage.width, cgImage.height) / gridSize * gridSize
        guard side > 0, let pixels = grayscalePixels(from: cgImage, side: side) else { return nil }
        let tileSide = side / gridSize
        var variance = 0.0
        for tileY in 0..<gridSize {
            for tileX in 0..<gridSize {
                var tile: [Float] = []
                tile.reserveCapacity(tileSide * tileSide)
                for y in 0..<tileSide {
                    let start = (tileY * tileSide + y) * side + tileX * tileSide
                    tile.append(contentsOf: pixels[start..<start + tileSide])
                }
                variance = max(variance, laplacianVariance(tile, side: tileSide))
            }
        }
        return 1 / (1 + variance / varianceScale)
    }

    static func blurScore(for image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        return blurScore(for: cgImage)
    }

    private static func grayscalePixels(from cgImage: CGImage, side: Int) -> [Float]? {
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels.map(Float.init)
    }

    /// Discrete Laplacian kernel: near zero on flat/blurred regions, large on sharp edges.
    /// Variance of the response is the classic Laplacian-variance sharpness measure.
    private static func laplacianVariance(_ pixels: [Float], side: Int) -> Double {
        var response = [Float](repeating: 0, count: pixels.count)
        var kernel: [Float] = [0, 1, 0, 1, -4, 1, 0, 1, 0]
        pixels.withUnsafeBufferPointer { src in
            response.withUnsafeMutableBufferPointer { dst in
                vDSP_f3x3(src.baseAddress!, vDSP_Length(side), vDSP_Length(side), &kernel, dst.baseAddress!)
            }
        }
        var mean: Float = 0
        vDSP_meanv(response, 1, &mean, vDSP_Length(response.count))
        var meanSquare: Float = 0
        vDSP_measqv(response, 1, &meanSquare, vDSP_Length(response.count))
        return max(Double(meanSquare) - Double(mean) * Double(mean), 0)
    }
}
