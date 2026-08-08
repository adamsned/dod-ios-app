import DODDomain
import XCTest

@testable import DODApp

/// A tap in the feed opens the recipe inside a left/right swipe pager over the
/// feed's ordered list (magazine-style), built by
/// ``TabStack/feedRecipeRoute(for:in:cookModeArmed:)``. This pins that pure
/// route-construction rule without a SwiftUI host: a real ordered list becomes a
/// `.recipeSeries` carrying it, while a degenerate context (a single recipe, e.g.
/// Surprise Me's `[item]`, or an item missing from the list) falls back to a
/// plain `.recipe` so there's nothing to page through.
final class FeedRecipeRouteTests: XCTestCase {

    private func makeItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id).",
            heroImage: nil,
            publishedAt: .distantPast,
            totalTimeDisplay: nil,
            canonicalURL: nil
        )
    }

    /// A tap on a recipe within a multi-item feed → `.recipeSeries` carrying the
    /// whole ordered list, opening on the tapped recipe's id.
    func test_multiItemFeed_buildsRecipeSeriesOpeningOnTappedRecipe() {
        let items = [makeItem(id: 1), makeItem(id: 2), makeItem(id: 3)]
        let route = TabStack.feedRecipeRoute(for: items[1], in: items, cookModeArmed: false)
        guard case .recipeSeries(let seriesItems, let startID, let autoStart) = route else {
            return XCTFail("expected .recipeSeries, got \(route)")
        }
        XCTAssertEqual(seriesItems.map(\.id), [1, 2, 3], "the full ordered list rides along for paging")
        XCTAssertEqual(startID, 2, "opens on the tapped recipe")
        XCTAssertFalse(autoStart)
    }

    /// A single-recipe context (Surprise Me hands `[item]`) has nothing to page
    /// through → plain `.recipe`, not a one-page series.
    func test_singleItemContext_degradesToPlainRecipe() {
        let item = makeItem(id: 7)
        let route = TabStack.feedRecipeRoute(for: item, in: [item], cookModeArmed: false)
        guard case .recipe(let recipe, _) = route else {
            return XCTFail("expected .recipe, got \(route)")
        }
        XCTAssertEqual(recipe.id, 7)
    }

    /// A tapped item somehow absent from the list → plain `.recipe` (defensive:
    /// the pager would have no page to open on).
    func test_itemNotInList_degradesToPlainRecipe() {
        let items = [makeItem(id: 1), makeItem(id: 2)]
        let route = TabStack.feedRecipeRoute(for: makeItem(id: 99), in: items, cookModeArmed: false)
        guard case .recipe(let recipe, _) = route else {
            return XCTFail("expected .recipe, got \(route)")
        }
        XCTAssertEqual(recipe.id, 99)
    }

    /// The Cook-Mode arm propagates onto the series so the opened page auto-starts
    /// (the pager only applies it to the opened page, not the ones swiped past).
    func test_cookModeArmed_propagatesToSeries() {
        let items = [makeItem(id: 1), makeItem(id: 2)]
        let route = TabStack.feedRecipeRoute(for: items[0], in: items, cookModeArmed: true)
        guard case .recipeSeries(_, _, let autoStart) = route else {
            return XCTFail("expected .recipeSeries, got \(route)")
        }
        XCTAssertTrue(autoStart)
    }
}
