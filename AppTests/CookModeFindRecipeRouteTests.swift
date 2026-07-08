import DODDomain
import XCTest

@testable import DODApp

/// DUT — the Cooking Tools hub's Cook Mode tile → explainer → "Find a Recipe"
/// routes the user to the Recipes (Feed) tab to pick a recipe, and that pick
/// should open ALREADY in Cook Mode (mirroring the `StartCookMode` deep link).
/// Before the fix the "Find a Recipe" hand-off just switched to the Feed tab and
/// the picked recipe routed with `autoStartCookMode: false`, dropping the
/// intent — the user landed on plain recipe detail and had to tap Cook Mode.
///
/// The mechanism is a one-shot "we came here to cook" arm: `RootView` sets it
/// before selecting `.feed`, and the Feed card tap builds its route through
/// ``TabStack/recipeRoute(for:cookModeArmed:)``, consuming the arm. This suite
/// pins that pure route-construction invariant without a SwiftUI host; the
/// downstream auto-start (`RecipeDetailView`'s `pendingAutoCookMode`) is the
/// same path the deep link already exercises.
final class CookModeFindRecipeRouteTests: XCTestCase {

    private func makeItem(id: Int = 42) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Dutch Oven Chili",
            excerpt: "A hearty campfire chili.",
            heroImage: nil,
            publishedAt: .distantPast,
            totalTimeDisplay: nil,
            canonicalURL: nil
        )
    }

    /// A recipe picked through the Cook Mode tool's "Find a Recipe" (the arm is
    /// set) routes with `autoStartCookMode: true`, so the recipe opens already in
    /// Cook Mode.
    func test_cookModeArmed_routesWithAutoStartCookModeTrue() {
        let route = TabStack.recipeRoute(for: makeItem(), cookModeArmed: true)
        guard case .recipe(let item, let autoStart) = route else {
            return XCTFail("expected a .recipe route, got \(route)")
        }
        XCTAssertEqual(item.id, 42)
        XCTAssertTrue(
            autoStart,
            "a recipe picked via the Cook Mode tool's Find a Recipe must auto-start Cook Mode"
        )
    }

    /// A normal Feed browse (the arm was never set) keeps today's behavior: plain
    /// recipe detail, no auto-start. This guards the scoping requirement that
    /// every other recipe-open path stays `false`.
    func test_notArmed_routesWithAutoStartCookModeFalse() {
        let route = TabStack.recipeRoute(for: makeItem(), cookModeArmed: false)
        guard case .recipe(_, let autoStart) = route else {
            return XCTFail("expected a .recipe route, got \(route)")
        }
        XCTAssertFalse(
            autoStart,
            "a plain Feed/Saved/Search/category tap must NOT auto-start Cook Mode"
        )
    }
}
