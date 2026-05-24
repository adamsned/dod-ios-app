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
    var recentlyViewedSet: Set<Int> = []
    var categories: [DODDomain.Category] = []

    func search(query: String) async throws -> [RecipeListItem] {
        searches.append(query)
        return results[query] ?? []
    }

    func searchIngredients(matching query: String) async throws -> [Int] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return localIngredientIDs[normalized] ?? []
    }

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        ids.compactMap { cachedItemsByID[$0] }
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func categoryIDs(forRecipeIDs ids: [Int]) async throws -> [Int: [Int]] {
        var result: [Int: [Int]] = [:]
        for id in ids {
            if let categoryIDs = categoryMap[id] {
                result[id] = categoryIDs
            }
        }
        return result
    }

    func totalSeconds(forRecipeIDs ids: [Int]) async throws -> [Int: Int] {
        var result: [Int: Int] = [:]
        for id in ids {
            if let seconds = totalSecondsMap[id] {
                result[id] = seconds
            }
        }
        return result
    }

    func recentlyViewedRecipeIDs() async throws -> Set<Int> { recentlyViewedSet }

    func allCategories() async throws -> [DODDomain.Category] { categories }

    func sendSearchTelemetry(queryHash: String) async {
        searchHashes.append(queryHash)
    }

    func isOnline() async -> Bool { online }
}
