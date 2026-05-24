import Foundation
import SwiftData

/// Schema V3 — adds local caching for comments + ratings (US-13, US-14).
///
/// Additive-only delta vs V2:
/// - `CachedComment` — one row per WP comment on a recipe post.
/// - `CachedRating` — one row per recipe, aggregate + this device's
///   user-rating value.
///
/// No existing field on `CachedRecipe` / `CachedListPage` / `CachedImage`
/// / `CachedIngredient` is touched. That makes the V2 → V3 migration a
/// **lightweight** stage: SwiftData extends the schema at container open,
/// no transform runs, no data is rewritten. Empty rows in the two new
/// tables are populated lazily as the user views recipes that have
/// comments or ratings — pre-existing caches keep working unchanged.
public enum SchemaV3: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            CachedRecipe.self,
            CachedListPage.self,
            CachedImage.self,
            CachedIngredient.self,  // from V2
            CachedComment.self,  // new in V3
            CachedRating.self,  // new in V3
        ]
    }
}
