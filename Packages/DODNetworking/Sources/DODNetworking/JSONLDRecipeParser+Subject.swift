import Foundation

/// DUT-544: the recipe-SUBJECT signal, split out of ``JSONLDRecipeParser`` so
/// the main type stays under SwiftLint's `type_body_length` cap.
extension JSONLDRecipeParser {

    /// Whether the page's JSON-LD carries a `@type: Recipe` node — the reliable
    /// "this page's SUBJECT is a recipe" signal.
    ///
    /// **Why (DUT-544).** DUT-538 forced the recipe path on the mere presence of
    /// a `wprm-recipe-container`, which over-classifies: a round-up / guide
    /// ARTICLE that embeds (or links) a WPRM card is now rendered as a bare
    /// recipe, losing its whole body. The distinguishing signal — validated
    /// 2026-07-04 against `dutch-oven-7-can-soup` (recipe) vs. the
    /// `dump-cake-recipes` / `memorial-day-recipes` / `dutch-oven-recipes`
    /// round-ups — is that the genuine recipe emits a top-level `Recipe`
    /// JSON-LD node while the round-ups do NOT (their `@type` is
    /// `Article` / `ItemList` / `CollectionPage`, and their embedded card emits
    /// no `Recipe` node). Preserves DUT-538 for 7 Can Soup: it HAS the Recipe
    /// node even though its `recipeIngredient` / `recipeInstructions` are empty.
    ///
    /// Reuses the same block-scan + `findRecipeObject` walk `parse` uses, so a
    /// `Recipe` node nested inside a `@graph` envelope is detected identically.
    public static func hasRecipeJSONLD(html: String) -> Bool {
        for raw in extractJSONLDBlocks(in: html) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) else {
                continue
            }
            if findRecipeObject(in: object) != nil {
                return true
            }
        }
        return false
    }
}
