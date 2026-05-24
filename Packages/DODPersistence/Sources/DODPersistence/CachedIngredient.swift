import Foundation
import SwiftData

/// Local index row of one normalized ingredient line tied to a `CachedRecipe`.
/// Multiple rows per recipe — one per ingredient — so we can run substring
/// queries with SwiftData `#Predicate` without re-parsing the JSON blob.
///
/// Populated lazily as recipes are viewed and JSON-LD parsed
/// (`RecipeStore.mergeDetail(_:)`). The index never has rows for recipes that
/// have never been opened — search falls back to title/excerpt for those.
///
/// Spec trace: US-12 / AC-12.1, AC-12.2. CL-16 documents the rationale for a
/// local index over a WP REST extension (none exists for recipe-body text).
@Model
public final class CachedIngredient {

    /// Recipe these ingredient lines belong to.
    public var recipeID: Int

    /// Lowercased, whitespace-trimmed ingredient text — the form a search
    /// predicate matches against. Original casing is not preserved here
    /// because the index is search-only; the user-visible text comes from
    /// `CachedRecipe.ingredientsJSON`.
    public var normalizedText: String

    public init(recipeID: Int, normalizedText: String) {
        self.recipeID = recipeID
        self.normalizedText = normalizedText
    }

    /// Canonical normalization used both when writing the index and when
    /// preparing a query string. Lowercased and trimmed of leading/trailing
    /// whitespace; the rest of the line is left intact so substring matches
    /// against quantities ("2 cloves garlic") still work.
    public static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
