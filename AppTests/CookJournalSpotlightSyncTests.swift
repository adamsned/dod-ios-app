import DODSupport
import Foundation
import Testing

@testable import DODApp

@Suite("CookJournalSpotlightSync") struct CookJournalSpotlightSyncTests {
    private func entry(_ index: Int) -> CookLogEntry {
        CookLogEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-\(String(format: "%012d", index))") ?? UUID(),
            recipeID: index,
            recipeTitle: "Recipe \(index)",
            cookedAt: Date(timeIntervalSince1970: TimeInterval(index * 86400)),
            note: nil,
            personalRating: nil,
            photoLocalID: nil
        )
    }

    private func id(_ entry: CookLogEntry) -> String { CookJournalSpotlightIndexer.identifier(for: entry.id) }

    @Test func staleIdentifiersAreThoseNoLongerPresent() {
        let firstEntry = entry(1)
        let secondEntry = entry(2)
        let stale = CookJournalSpotlightSync.staleIdentifiers(
            previous: [id(firstEntry), id(secondEntry)],
            entries: [firstEntry]
        )
        #expect(stale == [id(secondEntry)])
    }

    @Test func noStaleWhenUnchanged() {
        let firstEntry = entry(1)
        let stale = CookJournalSpotlightSync.staleIdentifiers(previous: [id(firstEntry)], entries: [firstEntry])
        #expect(stale.isEmpty)
    }
}
