import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// Regression coverage for the DUT concurrent-hydration reordering fix.
///
/// ``ShoppingListView/build(from:)`` hydrates every picked recipe's
/// ingredients CONCURRENTLY (a parallel fetch per recipe, for speed), then
/// hands the result to ``ShoppingListViewModel/add(recipes:)``. The old
/// implementation collected the concurrent hydrations with a bare
/// `for await recipe in group { out.append(recipe) }`, which yields tasks in
/// COMPLETION order, not submission order — so a fast (cached) recipe racing
/// ahead of a slow (network-fetched) one silently reordered the rows appended
/// to the shopping list. That breaks ``ShoppingListBuilderSheet``'s own
/// documented contract on `onBuild`: "Called with the user's selected recipes
/// (in `recipes` order)." ``ShoppingListView/hydrateInOrder(_:hydrate:)`` is
/// the fix — it keeps the hydration concurrent but re-seats each result at its
/// original index, so the returned order always matches the input order
/// regardless of which hydration lands first.
@MainActor
@Suite("ShoppingListView.hydrateInOrder concurrency ordering (DUT)")
struct ShoppingListViewHydrateOrderTests {

    /// Two recipes, submitted slow-then-fast; the SLOW one is submitted FIRST
    /// but finishes LAST. Completion-order collection would return
    /// `["Fast", "Slow"]`; the fix must still return `["Slow", "Fast"]` —
    /// matching the order they were passed in, not the order they finished.
    @Test func hydrationOrderMatchesInputOrderWhenTheFirstRecipeIsSlowest() async {
        let slow = Self.recipe(id: 1, title: "Slow")
        let fast = Self.recipe(id: 2, title: "Fast")

        let hydrated = await ShoppingListView.hydrateInOrder([slow, fast]) { recipe in
            if recipe.id == 1 {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return recipe
        }

        #expect(hydrated.map(\.title) == ["Slow", "Fast"])
    }

    /// Four recipes whose hydration completion order is the EXACT REVERSE of
    /// their input order (the last one submitted finishes first). This is the
    /// strongest proof: completion-order collection would return the fully
    /// reversed list; the fix must still return the original input order.
    @Test func hydrationOrderSurvivesFullyReversedCompletionTiming() async {
        let delaysByID: [Int: UInt64] = [
            1: 120_000_000,
            2: 80_000_000,
            3: 40_000_000,
            4: 0,
        ]
        let selected = [
            Self.recipe(id: 1, title: "Slowest"),
            Self.recipe(id: 2, title: "Slow"),
            Self.recipe(id: 3, title: "Fast"),
            Self.recipe(id: 4, title: "Fastest"),
        ]

        let hydrated = await ShoppingListView.hydrateInOrder(selected) { recipe in
            if let delay = delaysByID[recipe.id], delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            return recipe
        }

        #expect(hydrated.map(\.title) == ["Slowest", "Slow", "Fast", "Fastest"])
    }

    /// A single recipe is the degenerate case — no reordering possible, but
    /// pins that the happy path still returns the (only) hydrated recipe.
    @Test func singleRecipeHydratesUnchanged() async {
        let only = Self.recipe(id: 1, title: "Solo")

        let hydrated = await ShoppingListView.hydrateInOrder([only]) { $0 }

        #expect(hydrated.map(\.title) == ["Solo"])
    }

    /// An empty selection hydrates to an empty result (defensive — `build(from:)`
    /// is never called with an empty selection in practice, since the picker's
    /// "Confirm" is disabled at zero selections, but the helper itself
    /// shouldn't hang or crash on an empty task group).
    @Test func emptySelectionHydratesToEmptyResult() async {
        let hydrated: [Recipe] = await ShoppingListView.hydrateInOrder([]) { $0 }

        #expect(hydrated.isEmpty)
    }

    // MARK: - Fixtures

    static func recipe(id: Int, title: String) -> Recipe {
        Recipe(
            id: id,
            slug: "recipe-\(id)",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
