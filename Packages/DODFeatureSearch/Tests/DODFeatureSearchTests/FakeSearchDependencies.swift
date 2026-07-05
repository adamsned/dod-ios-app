import DODDomain
import Foundation

@testable import DODFeatureSearch

/// In-process double for `SearchDependencies` used by the view-model suite.
/// Tests poke `results`, `localIngredientIDs`, `categoryMap` etc. to set up
/// fixtures; the VM then runs against the fake exactly as it would against
/// `LiveSearchDependencies`.
final class FakeSearchDependencies: SearchDependencies, @unchecked Sendable {
    var results: [String: [RecipeListItem]] = [:]
    var online = true
    var searches: [String] = []
    var searchHashes: [String] = []
    var localIngredientIDs: [String: [Int]] = [:]
    var cachedItemsByID: [Int: RecipeListItem] = [:]
    var categoryMap: [Int: [Int]] = [:]
    var totalSecondsMap: [Int: Int] = [:]
    /// CL-106 (T-637): network-side cook-time map keyed by id. Returned
    /// by `fetchTotalSeconds(forRecipeIDs:)` to simulate the hydration
    /// path; tests assert that the cook-time filter narrows correctly
    /// after the values land.
    var networkTotalSecondsMap: [Int: Int] = [:]
    var networkTotalSecondsCalls: [[Int]] = []
    /// CL-106 (T-637): the "Latest Recipes" Try-pill fetch.
    var latestRecipes: [RecipeListItem] = []
    var latestRecipesCalls: [Int] = []
    /// CL-121 (T-643): the category-match path's `?categories=` fetch
    /// per matched category. Tests pre-seed `categoryFetchResults[id]`
    /// with the canned response for each category id the matcher will
    /// surface; the viewmodel reads the union-deduped result. Set
    /// `categoryFetchShouldThrow = true` to simulate the Path B failure
    /// branch (caller should still render Path A results — the graceful
    /// degradation contract CL-121 locks).
    var categoryFetchResults: [Int: [RecipeListItem]] = [:]
    var categoryFetchCalls: [(categoryID: Int, limit: Int)] = []
    var categoryFetchShouldThrow = false
    var recentlyViewedSet: Set<Int> = []
    var categories: [DODDomain.Category] = []
    /// CL-127 (T-649): pre-seed the "did you mean?" engine's source
    /// pool. Defaults to empty so tests that don't exercise the
    /// suggestion path implicitly land at `didYouMean == nil`.
    var cachedTitlesArray: [String] = []

    func search(query: String) async throws -> [RecipeListItem] {
        searches.append(query)
        return results[query] ?? []
    }

    func searchIngredients(matching query: String) async throws -> [Int] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return localIngredientIDs[normalized] ?? []
    }

    /// DUT-11: mirrors the live store query — resolve the matching ingredient
    /// IDs (via the same `localIngredientIDs` fixture the VM's old two-hop
    /// path used) and project to cached list items, deduped and order-
    /// preserving. Tests seed `localIngredientIDs[term]` + `cachedItemsByID`
    /// exactly as before, so existing fixtures keep working unchanged.
    func recipesUsingIngredient(matching query: String) async throws -> [RecipeListItem] {
        let ids = try await searchIngredients(matching: query)
        var seen: Set<Int> = []
        var items: [RecipeListItem] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            if let item = cachedItemsByID[id] {
                items.append(item)
            }
        }
        return items
    }

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        ids.compactMap { cachedItemsByID[$0] }
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    /// DUT-314: count the filter-support fetches so the perf-gate test can
    /// assert they are skipped on a default (no-filter) search.
    var categoryIDsCalls: [[Int]] = []
    var totalSecondsCalls: [[Int]] = []
    var recentlyViewedCallCount = 0

    func categoryIDs(forRecipeIDs ids: [Int]) async throws -> [Int: [Int]] {
        categoryIDsCalls.append(ids)
        var result: [Int: [Int]] = [:]
        for id in ids {
            if let categoryIDs = categoryMap[id] {
                result[id] = categoryIDs
            }
        }
        return result
    }

    func totalSeconds(forRecipeIDs ids: [Int]) async throws -> [Int: Int] {
        totalSecondsCalls.append(ids)
        var result: [Int: Int] = [:]
        for id in ids {
            if let seconds = totalSecondsMap[id] {
                result[id] = seconds
            }
        }
        return result
    }

    /// CL-106 (T-637): simulates the cook-time hydration network path.
    /// Tests pre-seed `networkTotalSecondsMap` for ids the cache lacks;
    /// the viewmodel's `kickOffCookTimeHydrationIfNeeded(...)` then
    /// updates `lastTotalSecondsByRecipe` and reapplies the filter.
    func fetchTotalSeconds(forRecipeIDs ids: [Int]) async -> [Int: Int] {
        networkTotalSecondsCalls.append(ids)
        var result: [Int: Int] = [:]
        for id in ids {
            if let seconds = networkTotalSecondsMap[id] {
                result[id] = seconds
            }
        }
        return result
    }

    /// CL-106 (T-637): simulates the "Latest Recipes" pill fetch path.
    /// Tests pre-seed `latestRecipes` with the canned response.
    func fetchLatestRecipes(limit: Int) async throws -> [RecipeListItem] {
        latestRecipesCalls.append(limit)
        return Array(latestRecipes.prefix(limit))
    }

    /// CL-121 (T-643): simulates the category-match path's `?categories=`
    /// fetch. Tests pre-seed `categoryFetchResults[id]` for each category
    /// id that the matcher will surface; the viewmodel reads them in match
    /// order and unions with Path A. Set `categoryFetchShouldThrow = true`
    /// to exercise the graceful-degradation branch (Path B failure must
    /// not block Path A — locked by `SearchViewModelT643Tests`).
    func fetchPosts(categoryID: Int, limit: Int) async throws -> [RecipeListItem] {
        categoryFetchCalls.append((categoryID: categoryID, limit: limit))
        if categoryFetchShouldThrow {
            throw NSError(domain: "FakeSearchDependencies", code: -643)
        }
        return Array((categoryFetchResults[categoryID] ?? []).prefix(limit))
    }

    func recentlyViewedRecipeIDs() async throws -> Set<Int> {
        recentlyViewedCallCount += 1
        return recentlyViewedSet
    }

    /// DUT-568 — an optional gate so a test can hold the "did you mean?"
    /// cached-titles fetch IN FLIGHT while it bumps the search generation,
    /// proving an older `computeDidYouMean` continuation re-checks the
    /// generation and does NOT clobber a newer search's banner. `nil`
    /// (default) = the fetch returns immediately; set to an async closure to
    /// suspend inside `cachedRecipeTitles()` before the fixture is returned.
    var cachedTitlesGate: (@Sendable () async -> Void)?

    /// DUT-574 — count the cached-titles fetches so a perf test can assert the
    /// "did you mean?" rescue path stays off the critical path (only consulted
    /// when the result set settles sparse).
    var cachedTitlesCallCount = 0

    /// CL-127 (T-649): returns the pre-seeded cached-titles fixture.
    func cachedRecipeTitles() async throws -> [String] {
        cachedTitlesCallCount += 1
        if let cachedTitlesGate { await cachedTitlesGate() }
        return cachedTitlesArray
    }

    func allCategories() async throws -> [DODDomain.Category] { categories }

    func sendSearchTelemetry(queryHash: String) async {
        searchHashes.append(queryHash)
    }

    func isOnline() async -> Bool { online }

    // DUT-534 Part 2 — the Shopping List append seam. `shoppingListResult`
    // stubs what the appender returns; `appendedRecipes` records the (minimal,
    // list-item-derived) recipes the view model handed over.
    var shoppingListResult: AddToShoppingListResult = .couldntLoad
    var appendedRecipes: [Recipe] = []
    /// DUT-541 — an optional gate so a test can hold an append IN FLIGHT while it
    /// launches a second concurrent add of the same id, proving the view model's
    /// in-flight guard drops the duplicate. `nil` (default) = append returns
    /// immediately; set to an async closure to suspend inside `addToShoppingList`
    /// after the recipe has been recorded.
    var appendGate: (@Sendable () async -> Void)?
    func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        appendedRecipes.append(recipe)
        if let appendGate { await appendGate() }
        return shoppingListResult
    }
}
