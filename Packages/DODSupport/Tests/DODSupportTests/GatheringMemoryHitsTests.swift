import Foundation
import Testing

@testable import DODSupport

@Suite("GatheringMemory hits (DUT-978)")
struct GatheringMemoryHitsTests {

    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(_ recipeID: Int, _ title: String) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: day)
    }

    private func record(hits: [CookLogEntry]) -> GatheringRecord {
        GatheringRecord(id: UUID(), day: day, headcount: 6, hitEntryIDs: hits.map(\.id))
    }

    @Test func hitsRankByGatheringCount() {
        let entryA1 = entry(1, "A")
        let entryA2 = entry(1, "A")
        let entryB1 = entry(2, "B")
        let result = GatheringMemory.hits(
            records: [record(hits: [entryB1, entryA1]), record(hits: [entryA2])],
            entries: [entryA1, entryA2, entryB1]
        )
        #expect(result.map(\.recipeID) == [1, 2])
        #expect(result.map(\.hitCount) == [2, 1])
    }

    @Test func unknownEntryIDsIgnored() {
        let entryA = entry(1, "A")
        let ghost = GatheringRecord(id: UUID(), day: day, headcount: 2, hitEntryIDs: [UUID(), entryA.id])
        let result = GatheringMemory.hits(records: [ghost], entries: [entryA])
        #expect(result.count == 1)
        #expect(result[0].recipeID == 1)
    }

    @Test func sameRecipeTwiceInOneGatheringCountsOnce() {
        let a1 = entry(1, "A")
        let a2 = entry(1, "A")
        let result = GatheringMemory.hits(records: [record(hits: [a1, a2])], entries: [a1, a2])
        #expect(result.count == 1)
        #expect(result[0].hitCount == 1)
    }

    @Test func limitIsRespected() {
        let dishes = (1...4).map { entry($0, "Dish \($0)") }
        let result = GatheringMemory.hits(records: [record(hits: dishes)], entries: dishes, limit: 2)
        #expect(result.count == 2)
        #expect(result.map(\.recipeTitle) == ["Dish 1", "Dish 2"])
    }
}
