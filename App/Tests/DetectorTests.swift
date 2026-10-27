import UIKit
import XCTest

final class DetectorTests: XCTestCase {
    /// Checkerboard of `cell`-px squares; larger cells = fewer edges = "blurrier" to the Laplacian.
    private func checkerboard(side: Int, cell: Int, smooth: Bool = false) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.setFill()
            for y in stride(from: 0, to: side, by: cell) {
                for x in stride(from: 0, to: side, by: cell) where (x / cell + y / cell).isMultiple(of: 2) {
                    context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
            if smooth {
                // Flat grey wash over everything: no edges left at all.
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
        }
    }

    func testSharpImageScoresBelowFlatImage() throws {
        let sharp = try XCTUnwrap(BlurDetector.blurScore(for: checkerboard(side: 512, cell: 4)))
        let flat = try XCTUnwrap(BlurDetector.blurScore(for: checkerboard(side: 512, cell: 4, smooth: true)))
        XCTAssertLessThan(sharp, 0.1)
        XCTAssertGreaterThan(flat, 0.99)
    }

    func testDHashIsStableAndDistinguishesImages() throws {
        let a = try XCTUnwrap(DuplicateDetector.dHash(checkerboard(side: 64, cell: 8)))
        let same = try XCTUnwrap(DuplicateDetector.dHash(checkerboard(side: 64, cell: 8)))
        let other = try XCTUnwrap(DuplicateDetector.dHash(checkerboard(side: 64, cell: 32)))
        XCTAssertEqual(DuplicateDetector.hammingDistance(a, same), 0)
        XCTAssertGreaterThan(DuplicateDetector.hammingDistance(a, other), 0)
    }

    func testGroupingNeedsSimilarHashAndTimeProximity() {
        let t0 = Date(timeIntervalSince1970: 0)
        let hashes: [UInt64?] = [0b0000, 0b0001, 0b0011, ~0, ~0, nil, ~0, ~0]
        let dates: [Date?] = [
            t0, t0 + 1, t0 + 2,          // similar burst → group
            t0 + 3,                      // very different hash → new run
            t0 + 10_000,                 // same hash but hours later → not grouped with previous
            t0 + 10_001,                 // nil hash breaks the run
            t0 + 10_002, t0 + 10_003,    // fresh pair → group
        ]
        XCTAssertEqual(
            DuplicateDetector.groupIndices(hashes: hashes, dates: dates, threshold: 2),
            [[0, 1, 2], [6, 7]]
        )
    }
}
