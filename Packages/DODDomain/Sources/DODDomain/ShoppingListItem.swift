import Foundation

/// One shopping-list row — captured per-recipe at insertion time.
///
/// **Per-recipe rows, no arithmetic (CL-69):** when the user adds three
/// recipes that all call for "1 yellow onion, diced", the shopping list
/// shows three separate rows — one per source recipe — each carrying the
/// `recipeTitle` as a sub-label attribution. We do **not** attempt
/// quantity arithmetic ("3 yellow onions") because the JSON-LD ingredient
/// strings on dutchovendaddy.com are free-form and merging them
/// reliably would require a parser deeper than the v1 scope can afford.
/// The cook can mentally collapse rows when shopping; the list keeps
/// the source attribution intact so they can revisit a recipe if needed.
///
/// **Why a value type (not a SwiftData `@Model` here):** this is the
/// domain shape — pure, `Sendable`, `Hashable`, `Codable`. The
/// persistence-layer counterpart lives in `DODPersistence` (T-682) as
/// a SwiftData `@Model` class with the same field shape; the view-model
/// translates between the two so the feature package's API surface stays
/// expressible in the domain vocabulary without leaking SwiftData types
/// into upstream packages.
///
/// **Mutability:** only `isChecked` is `var` — the per-row toggle per
/// AC-39.5 mutates this single field. Every other field is captured at
/// insertion time and never changes (the `recipeTitle` stays stable
/// across app launches even if `CachedRecipe` is LRU-evicted; the
/// `addedAt` timestamp pins the AC-39.4 within-aisle sort order).
///
/// Spec trace: US-39 / AC-39.2 (single-recipe add path — one row per
/// ingredient), AC-39.3 (multi-recipe add path — same per-row shape),
/// AC-39.5 (toggle), AC-39.8 (persistence), CL-69 (per-recipe rows
/// decision).
public struct ShoppingListItem: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public let recipeID: Int
    public let recipeTitle: String
    public let ingredientText: String
    public let aisle: Aisle
    public var isChecked: Bool
    public let addedAt: Date

    public init(
        id: UUID = UUID(),
        recipeID: Int,
        recipeTitle: String,
        ingredientText: String,
        aisle: Aisle,
        isChecked: Bool = false,
        addedAt: Date = .now
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.ingredientText = ingredientText
        self.aisle = aisle
        self.isChecked = isChecked
        self.addedAt = addedAt
    }
}
