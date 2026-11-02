import Foundation
import Testing

@testable import DODSupport

@Suite("CookoutPlan") struct CookoutPlanTests {

    private static let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

    private static func dish() -> CookoutPlan.Dish {
        CookoutPlan.Dish(recipeID: 1, title: "Cobbler", sourceServings: 4, cookMinutes: 45)
    }

    @Test func scaleFactorDoublesForEightGuestsAndFourServings() {
        let item = Self.dish()
        let plan = CookoutPlan(name: "Fourth", guestCount: 8, serveAt: Self.serveAt, dishes: [item])
        #expect(plan.scaleFactor(for: item) == 2.0)
    }

    @Test func zeroGuestsClampsToOne() {
        let plan = CookoutPlan(name: "Tiny", guestCount: 0, serveAt: Self.serveAt)
        #expect(plan.guestCount == 1)
    }

    @Test func codableRoundTripIsEqual() throws {
        let plan = CookoutPlan(name: "Fourth", guestCount: 8, serveAt: Self.serveAt, dishes: [Self.dish()])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let data = try encoder.encode(plan)
        let decoded = try decoder.decode(CookoutPlan.self, from: data)
        #expect(decoded == plan)
    }

    @Test func scaledIngredientsDoublesQuantity() {
        let item = Self.dish()
        let plan = CookoutPlan(name: "Fourth", guestCount: 8, serveAt: Self.serveAt, dishes: [item])
        let out = plan.scaledIngredients(["2 cups flour"], for: item)
        #expect(out.count == 1)
        #expect(out[0].contains("4"))
    }
}
