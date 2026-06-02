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

    // CloudKit needs every attribute optional-or-defaulted (DOD-CRASH-1);
    // defaults don't change the schema hash and `init` overwrites them.

    /// Recipe these ingredient lines belong to.
    public var recipeID: Int = 0

    /// Lowercased, whitespace-trimmed ingredient text — the form a search
    /// predicate matches against. Original casing is not preserved here
    /// because the index is search-only; the user-visible text comes from
    /// `CachedRecipe.ingredientsJSON`.
    public var normalizedText: String = ""

    public init(recipeID: Int, normalizedText: String) {
        self.recipeID = recipeID
        self.normalizedText = normalizedText
    }

    /// Canonical normalization used both when writing the index and when
    /// preparing a query string. Lowercased, diacritic-folded, and trimmed of
    /// leading/trailing whitespace; the rest of the line is left intact so
    /// substring matches against quantities ("2 cloves garlic") still work.
    ///
    /// DUT-11 adds the diacritic fold so an accented ingredient ("jalapeño",
    /// "crème fraîche") matches an un-accented query and vice-versa. The fold
    /// is applied symmetrically — both the stored `normalizedText` and the
    /// query pass through here — so the substring predicate stays consistent.
    /// The index is repopulated lazily on `mergeDetail(_:)` (one row per
    /// ingredient line as recipes are opened), so rows written before this
    /// change pick up the folded form the next time their recipe is viewed.
    public static func normalize(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
