import DODDomain
import Foundation
import SwiftData

/// US-12 ingredient-index methods on `RecipeStore`. Kept in a separate file
/// from `RecipeStore.swift` so the main store stays under the SwiftLint
/// file-length budget (constitution §10).
///
/// Spec trace: US-12 / AC-12.1 (ingredient-aware ranking),
/// AC-12.3 (filter composition), AC-12.5 (< 200ms local search).
extension RecipeStore {

    /// Substring-match the local ingredient index. Returns the recipe IDs
    /// that contain at least one ingredient line where
    /// ``CachedIngredient.normalizedText`` contains the (lowercased,
    /// trimmed) query. Order is unspecified — callers should re-rank merged
    /// results explicitly (see `SearchResultMerger`).
    public func searchIngredients(matching query: String) throws -> [Int] {
        let normalized = CachedIngredient.normalize(query)
        guard normalized.count >= 2 else { return [] }
        let descriptor = FetchDescriptor<CachedIngredient>(
            predicate: #Predicate { row in
                row.normalizedText.contains(normalized)
            }
        )
        let rows = try modelContext.fetch(descriptor)
        // Stable dedupe in fetch order so behavior is deterministic for tests.
        var seen: Set<Int> = []
        var ordered: [Int] = []
        for row in rows where !seen.contains(row.recipeID) {
            seen.insert(row.recipeID)
            ordered.append(row.recipeID)
        }
        return ordered
    }

    /// Test/debug accessor: how many index rows exist for a given recipe.
    /// Production code has no reason to call this; tests assert on it.
    public func ingredientIndexCount(forRecipeID id: Int) throws -> Int {
        let descriptor = FetchDescriptor<CachedIngredient>(
            predicate: #Predicate { $0.recipeID == id }
        )
        return try modelContext.fetch(descriptor).count
    }

    /// Drop every index row for the recipe and re-insert from the freshly
    /// parsed ingredients. Called from `RecipeStore.mergeDetail(_:)` so a
    /// re-parse with corrected text replaces stale entries instead of
    /// accumulating duplicates.
    func replaceIngredientIndexRows(
        forRecipeID id: Int,
        with ingredients: [RecipeIngredient]
    ) throws {
        let descriptor = FetchDescriptor<CachedIngredient>(
            predicate: #Predicate { $0.recipeID == id }
        )
        for stale in try modelContext.fetch(descriptor) {
            modelContext.delete(stale)
        }
        for ingredient in ingredients {
            let normalized = CachedIngredient.normalize(ingredient.text)
            guard !normalized.isEmpty else { continue }
            modelContext.insert(
                CachedIngredient(recipeID: id, normalizedText: normalized)
            )
        }
    }

    // MARK: - Search-filter inputs (US-12 / AC-12.3)

    /// Return `recipeID -> [WP category IDs]` for the given ids. Recipes not
    /// present in the local cache are simply omitted from the result.
    public func categoryIDs(forRecipeIDs ids: [Int]) throws -> [Int: [Int]] {
        guard !ids.isEmpty else { return [:] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { row in idSet.contains(row.id) }
        )
        let rows = try modelContext.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.categoryIDs) })
    }

    /// Return `recipeID -> total time in seconds` for the given ids.
    /// Recipes that haven't been parsed yet (and so lack `totalSeconds`)
    /// are omitted — `SearchFilters` treats absence as a MISS for the
    /// cook-time chip.
    public func totalSeconds(forRecipeIDs ids: [Int]) throws -> [Int: Int] {
        guard !ids.isEmpty else { return [:] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { row in idSet.contains(row.id) }
        )
        let rows = try modelContext.fetch(descriptor)
        var result: [Int: Int] = [:]
        for row in rows {
            if let totalSeconds = row.totalSeconds {
                result[row.id] = totalSeconds
            }
        }
        return result
    }

    /// Set of recipe IDs the user has *opened* (any row present in the
    /// cache, regardless of save state). Drives the "Recently viewed"
    /// filter chip.
    public func recentlyViewedRecipeIDs() throws -> Set<Int> {
        let descriptor = FetchDescriptor<CachedRecipe>()
        let rows = try modelContext.fetch(descriptor)
        return Set(rows.map(\.id))
    }
}
