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
/// The mechanism is a "we came here to cook" arm: `RootView` sets it before
/// selecting `.feed`, and the Feed card tap builds its route through
/// ``TabStack/recipeRoute(for:cookModeArmed:)``. This suite pins that pure
/// route-construction invariant without a SwiftUI host; the downstream
/// auto-start (`RecipeDetailView`'s `pendingAutoCookMode`) is the same path
/// the deep link already exercises.
///
/// DUT-1229 — the arm used to disarm itself the instant the FIRST pick
/// consumed it (in `TabStack`'s `onSelect` closure), so backing out of Cook
/// Mode and picking a DIFFERENT recipe silently stopped auto-starting: "works
/// once, not the second time," exactly as reported. The arm now stays armed
/// across repeated picks and only disarms via
/// ``RootView/shouldDisarmCookModeFind(forTab:)`` when the user leaves the
/// Feed tab — pinned below alongside the pre-existing route-construction tests.
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

    /// DUT-1229 regression: staying on the Feed tab must NOT disarm — this is
    /// exactly what lets a SECOND, different recipe pick (after backing out of
    /// Cook Mode) still auto-start, without the user re-tapping "Find a Recipe."
    func test_stayingOnFeed_doesNotDisarm() {
        XCTAssertFalse(RootView.shouldDisarmCookModeFind(forTab: .feed))
    }

    /// DUT-1229 regression: leaving Feed for ANY other tab disarms — the
    /// natural end of the "I came here to cook" session.
    func test_leavingFeedForAnyOtherTab_disarms() {
        for tab in AppTab.allCases where tab != .feed {
            XCTAssertTrue(
                RootView.shouldDisarmCookModeFind(forTab: tab),
                "leaving Feed for \(tab) must disarm the Cook Mode Find-a-Recipe flag"
            )
        }
    }
}
