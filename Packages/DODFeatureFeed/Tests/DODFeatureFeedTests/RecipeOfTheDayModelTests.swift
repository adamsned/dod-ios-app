import DODAnalytics
import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

final class RecipeOfTheDayEventBox {
    var events: [AnalyticsEvent] = []
}

@MainActor
@Suite("RecipeOfTheDayModel (DUT-117)")
struct RecipeOfTheDayModelTests {
    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(id: id, title: "R\(id)", excerpt: "", publishedAt: Date(timeIntervalSince1970: 0))
    }

    static func items(_ ids: ClosedRange<Int>) -> [RecipeListItem] {
        ids.map(makeItem)
    }

    static func makeModel(
        defaults: UserDefaults,
        now: Date = Date(timeIntervalSince1970: 1_800_000_000),
        sent: RecipeOfTheDayEventBox = RecipeOfTheDayEventBox()
    ) -> RecipeOfTheDayModel {
        RecipeOfTheDayModel(
            store: RecipeOfTheDayStore(defaults: defaults),
            now: { now },
            send: { sent.events.append($0) }
        )
    }

    static func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString) ?? .standard
    }

    @Test func emptyPoolLeavesItemNil() async {
        let model = Self.makeModel(defaults: Self.freshDefaults())
        await model.resolve(pool: [], lookup: { _ in [] })
        #expect(model.item == nil)
    }

    @Test func pickIsStableAcrossResolvesEvenWhenPoolChanges() async {
        let model = Self.makeModel(defaults: Self.freshDefaults())
        await model.resolve(pool: Self.items(1...10), lookup: { _ in [] })
        let firstID = model.item?.id
        #expect(firstID != nil)
        await model.resolve(pool: Self.items(11...20), lookup: { _ in [] })
        #expect(model.item?.id == firstID)
    }

    @Test func usesLookupWhenStoredPickIsNotInPool() async {
        let defaults = Self.freshDefaults()
        let first = Self.makeModel(defaults: defaults)
        await first.resolve(pool: Self.items(1...10), lookup: { _ in [] })
        let firstID = first.item?.id
        #expect(firstID != nil)

        let second = Self.makeModel(defaults: defaults)
        await second.resolve(pool: [], lookup: { ids in ids.map(Self.makeItem) })
        #expect(second.item?.id == firstID)
    }
}
