import CoreSpotlight
import Foundation
import UIKit
import XCTest

@testable import DODApp

/// DUT-467 — the Spotlight (re)index must not materialize all ~60 full-res hero
/// JPEGs at once. ``SpotlightIndexer`` bounds peak memory on two axes, both pinned
/// here via injected seams (no real memory probe, no SwiftUI host):
///
/// - **Batching** — items are indexed in batches of at most `batchSize`, so no
///   more than `batchSize` thumbnail blobs are held concurrently. A spy counts
///   the blobs alive in each delivered batch and asserts the peak never exceeds
///   the bound (the old path handed all 60 to one `indexSearchableItems` call).
/// - **Downsampling** — every cached hero blob is routed through the downsample
///   seam before being attached, so a retained blob is a small thumbnail, not a
///   full-res original (which also removes the old 1 MB skip-guard).
///
/// And the CoreSpotlight behavior is preserved: the SAME searchable items (one
/// per payload, same identifiers) are still emitted across the batches.
final class SpotlightIndexerTests: XCTestCase {

    private func payload(id: Int, hasHero: Bool = true) -> RecipeEntityPayload {
        RecipeEntityPayload(
            id: id,
            title: "Recipe \(id)",
            excerpt: "excerpt \(id)",
            heroImage: hasHero ? URL(string: "https://example.com/hero-\(id).jpg") : nil,
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/recipe-\(id)/")
        )
    }

    /// The peak number of thumbnail blobs held at once is bounded by `batchSize`,
    /// and every payload still becomes exactly one searchable item.
    func testIndexingIsBatchedAndBoundsConcurrentBlobs() async throws {
        let batchSize = 12
        let payloads = (1...60).map { payload(id: $0) }

        // A "full-res" original the downsample seam shrinks to a small thumbnail.
        let fullRes = Data(repeating: 0xAB, count: 900_000)
        let thumb = Data(repeating: 0xCD, count: 4_000)

        let downsampleCalls = Counter()
        let peakBatch = Counter()
        var deliveredIDs: [String] = []
        var deliveredThumbnailBytes: [Int] = []

        let indexer = SpotlightIndexer(
            batchSize: batchSize,
            cachedHeroBytes: { _ in fullRes },
            downsample: { data, maxPixel in
                XCTAssertEqual(data.count, fullRes.count, "seam should see the full-res original")
                XCTAssertEqual(maxPixel, 300)
                downsampleCalls.increment()
                return thumb
            },
            indexBatch: { batch in
                // Each delivered batch is the set of blobs held concurrently; the
                // indexer clears it before building the next, so batch size is the
                // concurrent-blob high-water mark.
                peakBatch.max(batch.count)
                for item in batch {
                    deliveredIDs.append(item.uniqueIdentifier)
                    deliveredThumbnailBytes.append(item.attributeSet.thumbnailData?.count ?? 0)
                }
            }
        )

        try await indexer.index(payloads: payloads)

        // Batched: never more than batchSize blobs at once (old path = all 60).
        XCTAssertLessThanOrEqual(peakBatch.value, batchSize)
        XCTAssertEqual(peakBatch.value, batchSize, "full batches should fill to the bound")
        // Downsample ran once per hero blob, not skipped.
        XCTAssertEqual(downsampleCalls.value, payloads.count)
        // Searchable-item behavior preserved: one item per payload, stable ids.
        XCTAssertEqual(deliveredIDs.count, payloads.count)
        XCTAssertEqual(Set(deliveredIDs).count, payloads.count)
        XCTAssertEqual(deliveredIDs.first, "dod.recipe.1")
        // Every attached thumbnail is the small downsampled blob, never the original.
        XCTAssertTrue(deliveredThumbnailBytes.allSatisfy { $0 == thumb.count })
    }

    /// A payload count that isn't a multiple of `batchSize` still delivers every
    /// item — the trailing partial batch is flushed.
    func testTrailingPartialBatchIsFlushed() async throws {
        let payloads = (1...5).map { payload(id: $0) }
        var deliveredCount = 0
        var batches = 0
        let indexer = SpotlightIndexer(
            batchSize: 2,
            cachedHeroBytes: { _ in nil },
            downsample: { _, _ in nil },
            indexBatch: { batch in
                batches += 1
                deliveredCount += batch.count
            }
        )
        try await indexer.index(payloads: payloads)
        XCTAssertEqual(deliveredCount, 5)
        XCTAssertEqual(batches, 3)  // 2 + 2 + 1
    }

    /// A payload whose hero isn't cached leaves the thumbnail nil and never calls
    /// the downsample seam — parity with the pre-DUT-467 "leave thumbnail nil".
    func testUncachedHeroLeavesThumbnailNil() async throws {
        var downsampled = false
        var nilThumbnails = 0
        let indexer = SpotlightIndexer(
            batchSize: 10,
            cachedHeroBytes: { _ in nil },
            downsample: { _, _ in
                downsampled = true
                return Data()
            },
            indexBatch: { batch in
                nilThumbnails += batch.filter { $0.attributeSet.thumbnailData == nil }.count
            }
        )
        try await indexer.index(payloads: (1...3).map { payload(id: $0, hasHero: false) })
        XCTAssertFalse(downsampled)
        XCTAssertEqual(nilThumbnails, 3)
    }

    /// The default ImageIO downsampler actually shrinks a real JPEG's byte size
    /// (bounds the retained blob), proving the memory win is real, not just the seam.
    func testImageIODownsampleShrinksRealJPEG() throws {
        // A 1024×1024 opaque red JPEG is far larger than its 300px thumbnail.
        let big = Self.makeJPEG(side: 1024)
        let small = try XCTUnwrap(SpotlightIndexer.imageIODownsample(big, maxPixel: 300))
        XCTAssertLessThan(small.count, big.count)
        XCTAssertGreaterThan(small.count, 0)
    }

    // MARK: - Helpers

    /// A tiny thread-safe counter so the async seams can tally without data races.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = 0
        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        func increment() {
            lock.lock()
            defer { lock.unlock() }
            _value += 1
        }
        func max(_ candidate: Int) {
            lock.lock()
            defer { lock.unlock() }
            if candidate > _value { _value = candidate }
        }
    }

    private static func makeJPEG(side: Int) -> Data {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1.0) ?? Data()
    }
}
