import DODSupport
import Foundation

/// The shared "Use Metric Units" append-time rewrite. Split out of
/// `ShoppingListViewModel.swift` so that file stays under SwiftLint's
/// `file_length` (400-line) cap — same split pattern used across the codebase
/// (mirrors `+Dedup` / `+Mock`).
extension ShoppingListViewModel {

    /// Rewrite each row's `ingredientText` to metric when the shared "Use
    /// Metric Units" preference is on; a transparent pass-through otherwise (or
    /// when a row's text isn't confidently convertible —
    /// ``IngredientMetricConverter/metric(_:)`` already returns those
    /// unchanged).
    ///
    /// The single shared choke point for this rewrite: ``LiveShoppingListAppender``
    /// (the Recipe Detail / Feed / Search single-recipe "Add to Shopping List")
    /// and ``add(recipes:)`` (the Saved-tab bulk picker) both apply it to rows
    /// built by ``rows(from:)`` before they land on the list, so a cook sees the
    /// same unit system no matter which surface they used to add.
    static func applyMetricPreference(_ rows: [Item], defaults: UserDefaults) -> [Item] {
        guard defaults.bool(forKey: IngredientMetricConverter.preferenceKey) else { return rows }
        return rows.map { row in
            Item(
                id: row.id,
                ingredientText: IngredientMetricConverter.metric(row.ingredientText),
                recipeTitle: row.recipeTitle,
                aisle: row.aisle
            )
        }
    }
}
