import CoreSpotlight
import DODSupport
import Foundation
import XCTest

@testable import DODApp

/// DUT-1018 — tests for the cook journal spotlight indexer.
final class CookJournalSpotlightIndexerTests: XCTestCase {

    private final class Box: @unchecked Sendable {
        var items: [CSSearchableItem] = []
        var batchSizes: [Int] = []
    }

    private func entry(id: Int, photoLocalID: String? = nil) -> CookLogEntry {
        CookLogEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-\(String(format: "%012d", id))") ?? UUID(),
            recipeID: id,
            recipeTitle: "Recipe \(id)",
            cookedAt: Date(timeIntervalSince1970: TimeInterval(id * 86400)),
            note: "Note \(id)",
            personalRating: nil,
            photoLocalID: photoLocalID
        )
    }

    /// One item per entry with stable identifiers.
    func testOneItemPerEntryWithStableIdentifiers() async throws {
        let entries = (1...3).map { entry(id: $0) }

        let box = Box()
        let indexer = CookJournalSpotlightIndexer(
            batchSize: 10,
            photoBytes: { _ in nil },
            indexBatch: { batch in
                box.items.append(contentsOf: batch)
            }
        )

        try await indexer.index(entries: entries)

        XCTAssertEqual(box.items.count, 3)
        for (index, item) in box.items.enumerated() {
            let expectedID = "dod.cookjournal.\(entries[index].id.uuidString)"
            XCTAssertEqual(item.uniqueIdentifier, expectedID)
            XCTAssertEqual(item.domainIdentifier, CookJournalSpotlightIndexer.domainIdentifier)
        }
    }

    /// Batching works correctly.
    func testBatchesAtBatchSize() async throws {
        let entries = (1...5).map { entry(id: $0) }

        let box = Box()
        let indexer = CookJournalSpotlightIndexer(
            batchSize: 2,
            photoBytes: { _ in nil },
            indexBatch: { batch in
                box.batchSizes.append(batch.count)
            }
        )

        try await indexer.index(entries: entries)

        XCTAssertEqual(box.batchSizes, [2, 2, 1])
    }

    /// Photo bytes are routed through the downsample function.
    func testPhotoRoutedThroughDownsample() async throws {
        let entries = [
            entry(id: 1, photoLocalID: "a.jpg"),
            entry(id: 2, photoLocalID: nil),
        ]

        let box = Box()

        let indexer = CookJournalSpotlightIndexer(
            batchSize: 10,
            photoBytes: { id in
                XCTAssertEqual(id, "a.jpg")
                return Data([1, 2, 3])
            },
            downsample: { data, maxPixel in
                XCTAssertEqual(data, Data([1, 2, 3]))
                XCTAssertEqual(maxPixel, 300)
                return Data([9])
            },
            indexBatch: { batch in
                box.items.append(contentsOf: batch)
            }
        )

        try await indexer.index(entries: entries)

        // First entry should have thumbnail data
        XCTAssertEqual(box.items[0].attributeSet.thumbnailData, Data([9]))

        // Second entry should not have thumbnail data
        XCTAssertNil(box.items[1].attributeSet.thumbnailData)
    }
}
