import DODDomain
import Foundation

/// DUT — split out of `ShoppingListView.swift` so that file stays under
/// SwiftLint's `file_length` (400-line) cap — same split pattern used across
/// the codebase (e.g. `ShoppingListViewModel+Dedup.swift`).
extension ShoppingListView {

    /// Hydrate `recipes` concurrently (parallel fetches, for speed — unchanged
    /// from before), while guaranteeing the returned array's order always
    /// matches `recipes`' input order, regardless of which hydration finishes
    /// first. Each task is tagged with its original index and the result is
    /// re-seated at that index, rather than appended in completion order.
    ///
    /// **The bug this fixes.** `build(from:)` used to collect the concurrent
    /// hydrations with a bare `for await recipe in group { out.append(recipe) }`.
    /// `for await` over a `TaskGroup` yields tasks in COMPLETION order, not
    /// submission order, so a cached/fast recipe's hydration racing ahead of a
    /// slow network fetch silently reordered the rows appended to the Shopping
    /// List — breaking ``ShoppingListBuilderSheet``'s own documented contract
    /// on `onBuild`: "Called with the user's selected recipes (in `recipes`
    /// order)." This restores that guarantee while keeping the hydration
    /// concurrent (no serialization / performance regression).
    ///
    /// `static` + module-internal (not `private`) so it's directly unit-tested
    /// via `@testable import` without driving the whole view / sheet.
    static func hydrateInOrder(
        _ recipes: [Recipe],
        hydrate: @escaping @Sendable (Recipe) async -> Recipe
    ) async -> [Recipe] {
        await withTaskGroup(of: (Int, Recipe).self) { group in
            for (index, recipe) in recipes.enumerated() {
                group.addTask { (index, await hydrate(recipe)) }
            }
            var slots = [Recipe?](repeating: nil, count: recipes.count)
            for await (index, recipe) in group {
                slots[index] = recipe
            }
            // Every index 0..<recipes.count receives exactly one task's
            // result above, so no slot is ever left nil; `compactMap` just
            // unwraps without ever dropping a row (never a force-unwrap).
            return slots.compactMap { $0 }
        }
    }
}
