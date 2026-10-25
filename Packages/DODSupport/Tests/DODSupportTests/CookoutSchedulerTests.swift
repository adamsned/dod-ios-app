import Foundation
import Testing

@testable import DODSupport

@Suite("CookoutScheduler") struct CookoutSchedulerTests {

    private static let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

    private static func plan() -> CookoutPlan {
        let stew = CookoutPlan.Dish(
            recipeID: 1,
            title: "Stew",
            sourceServings: 4,
            isBaking: false,
            ovenDiameterInches: 12,
            cookMinutes: 60
        )
        let cobbler = CookoutPlan.Dish(
            recipeID: 2,
            title: "Cobbler",
            sourceServings: 4,
            isBaking: true,
            ovenDiameterInches: 10,
            cookMinutes: 30
        )
        return CookoutPlan(name: "Fourth", guestCount: 8, serveAt: serveAt, dishes: [cobbler, stew])
    }

    @Test func longestDishStartsFirstAtBackTimedInstant() {
        let entries = CookoutScheduler.schedule(for: Self.plan())
        #expect(entries.count == 2)
        #expect(entries[0].recipeID == 1)
        #expect(entries[0].startAt == Self.serveAt.addingTimeInterval(-3600))
        #expect(entries[1].startAt == Self.serveAt.addingTimeInterval(-1800))
    }

    @Test func totalCoalsSumsEveryDish() {
        #expect(CookoutScheduler.totalCoals(for: Self.plan()) == 44)
    }

    @Test func emptyPlanGivesNothing() {
        let empty = CookoutPlan(name: "Empty", guestCount: 4, serveAt: Self.serveAt)
        #expect(CookoutScheduler.schedule(for: empty).isEmpty)
        #expect(CookoutScheduler.totalCoals(for: empty) == 0)
    }
}
