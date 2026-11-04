import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("RecipeOfTheDayPicker (DUT-117)")
struct RecipeOfTheDayPickerTests {
    private func items(_ ids: ClosedRange<Int>) -> [RecipeListItem] {
        ids.map {
            RecipeListItem(id: $0, title: "R\($0)", excerpt: "", publishedAt: Date(timeIntervalSince1970: 0))
        }
    }

    @Test func emptyPoolReturnsNil() {
        #expect(RecipeOfTheDayPicker.pick(from: [], dayKey: "2026-10-01", excluding: []) == nil)
    }

    @Test func sameDayKeyIsDeterministicAndOrderIndependent() {
        let pool = items(1...10)
        let forward = RecipeOfTheDayPicker.pick(from: pool, dayKey: "2026-10-01", excluding: [])
        let reversed = RecipeOfTheDayPicker.pick(from: Array(pool.reversed()), dayKey: "2026-10-01", excluding: [])
        #expect(forward != nil)
        #expect(forward?.id == reversed?.id)
    }

    @Test func excludesRecentIDs() {
        let picked = RecipeOfTheDayPicker.pick(
            from: items(1...10),
            dayKey: "2026-10-05",
            excluding: [1, 2, 3, 4, 5, 6, 7, 8, 9]
        )
        #expect(picked?.id == 10)
    }

    @Test func fallsBackToWholePoolWhenAllRecent() {
        let picked = RecipeOfTheDayPicker.pick(from: items(1...3), dayKey: "2026-10-05", excluding: [1, 2, 3])
        #expect(picked != nil)
    }

    @Test func differentDaysCanDiffer() {
        let pool = items(1...10)
        var ids = Set<Int>()
        for day in 1...28 {
            let key = "2026-10-" + (day < 10 ? "0\(day)" : "\(day)")
            if let id = RecipeOfTheDayPicker.pick(from: pool, dayKey: key, excluding: [])?.id {
                ids.insert(id)
            }
        }
        #expect(ids.count > 1)
    }
}
