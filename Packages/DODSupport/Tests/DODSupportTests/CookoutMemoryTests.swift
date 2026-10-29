import Foundation
import Testing

@testable import DODSupport

@Suite("CookoutMemory") struct CookoutMemoryTests {

    static func plan(dishes: [CookoutPlan.Dish] = []) -> CookoutPlan {
        CookoutPlan(
            name: "Family Cookout",
            guestCount: 12,
            serveAt: Date(timeIntervalSince1970: 1_700_000_000),
            dishes: dishes
        )
    }

    @Test func countOfLovedCountsOnlyThatReaction() {
        let memory = CookoutMemory(plan: Self.plan(), reactions: [.loved, .seconds, .loved])
        #expect(memory.count(of: .loved) == 2)
        #expect(memory.count(of: .seconds) == 1)
        #expect(memory.count(of: .askedForRecipe) == 0)
    }

    @Test func codableRoundTripIsEqual() throws {
        let dish = CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90)
        let memory = CookoutMemory(
            plan: Self.plan(dishes: [dish]),
            photoFilenames: ["a.jpg"],
            reactions: [.loved, .askedForRecipe]
        )
        let data = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(CookoutMemory.self, from: data)
        #expect(decoded == memory)
    }

    @Test func headlineTellsTheStoryWithDishesAndAsks() {
        let dishes = [
            CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90),
            CookoutPlan.Dish(recipeID: 2, title: "Cobbler", sourceServings: 8, isBaking: true, cookMinutes: 45),
        ]
        let memory = CookoutMemory(
            plan: Self.plan(dishes: dishes),
            reactions: [.askedForRecipe, .askedForRecipe, .askedForRecipe]
        )
        #expect(memory.headline == "Fed 12 with Chili & Cobbler — 3 asked for the recipe")
    }

    @Test func headlineWithNoDishesAndNoReactionsIsJustFed() {
        let memory = CookoutMemory(plan: Self.plan())
        #expect(memory.headline == "Fed 12")
    }
}
