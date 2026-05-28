import DODSupport
import Foundation

/// Builds the plain-text / Markdown share payload for the shopping list
/// (US-39 / AC-39.7).
///
/// Spec trace: AC-39.7 (the system share sheet wraps a single plain-text item),
/// CL-85 (this slice's share-text shape + the deliberate exclusion of checked +
/// already-have rows). CL-85 records this exclusion as an intentional deviation
/// from CL-72 ("always the full list, not just unchecked items"): the round-8
/// entry/share re-scope shares the *actionable still-need subset* — the items
/// the recipient actually has to buy — so rows the cook already has
/// ("I already have this") or has already grabbed (checked off while shopping)
/// are omitted. The exclusion is a single `filter`; passing `includeChecked: true`
/// restores CL-72's full-list snapshot if a future pass wants it.
///
/// Pure + deterministic + no I/O — never touches `URLSession` (REG-23 /
/// AC-39.12: the shopping-list feature makes zero network calls).
public enum ShoppingListFormatter {

    /// Build the share text for a shopping list.
    ///
    /// Format (Markdown-friendly plain text):
    /// ```
    /// Shopping List
    ///
    /// Produce
    /// - 2 limes (Skillet Chicken Tacos)
    /// - 4 carrots, peeled (Dutch Oven Pot Roast)
    ///
    /// Meat & Seafood
    /// - 1 lb chicken thighs (Skillet Chicken Tacos)
    /// ```
    /// Aisles render in `Aisle.allCases` store-walk order (AC-39.4); only
    /// aisles with at least one shared row appear. Each row is
    /// `- <ingredient text> (<recipe title>)`.
    ///
    /// - Parameters:
    ///   - viewModel: the shopping list whose still-need rows are shared.
    ///   - includeChecked: when `false` (default, CL-85), rows the user has
    ///     checked off are excluded; when `true`, the full still-need list
    ///     (everything not marked "already have") is shared — CL-72's snapshot.
    /// - Returns: the share string. When no rows qualify, returns just the
    ///   `"Shopping List"` header so the share target still receives non-empty
    ///   text.
    @MainActor
    public static func shareText(
        _ viewModel: ShoppingListViewModel,
        includeChecked: Bool = false
    ) -> String {
        // `visibleItems` already drops "I already have this" rows. Then drop
        // checked rows too (unless the caller opts into the full snapshot).
        let rows = viewModel.visibleItems.filter { item in
            includeChecked || !viewModel.isChecked(item)
        }
        return shareText(for: rows)
    }

    /// Pure value-level overload — builds the share text from explicit rows so
    /// tests can assert against it without an `@Observable` instance. The rows
    /// are assumed to already be filtered to the share subset.
    public static func shareText(for rows: [ShoppingListViewModel.Item]) -> String {
        let header = "Shopping List"
        guard !rows.isEmpty else { return header }

        let grouped = Dictionary(grouping: rows, by: \.aisle)
        let blocks: [String] = IngredientAisleClassifier.Aisle.allCases.compactMap { aisle in
            guard let aisleRows = grouped[aisle], !aisleRows.isEmpty else { return nil }
            let lines = aisleRows.map { "- \($0.ingredientText) (\($0.recipeTitle))" }
            return ([displayName(aisle)] + lines).joined(separator: "\n")
        }

        return ([header] + blocks).joined(separator: "\n\n")
    }

    /// AC-39.4 aisle display names for the six shipped logic-core cases
    /// (mirrors `ShoppingListView`'s inline `AisleHeader.displayName`; `meat`
    /// renders "Meat & Seafood" per AC-39.4, folding seafood in per CL-80).
    static func displayName(_ aisle: IngredientAisleClassifier.Aisle) -> String {
        switch aisle {
        case .produce: "Produce"
        case .meat: "Meat & Seafood"
        case .dairy: "Dairy"
        case .pantry: "Pantry"
        case .spices: "Spices"
        case .other: "Other"
        }
    }
}
