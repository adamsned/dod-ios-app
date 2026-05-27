import Foundation
import SwiftData

/// Schema V4 — adds the article-body cache column for US-37 / CL-63 / T-640.
///
/// Additive-only delta vs V3:
/// - `CachedRecipe.articleBodyHTML: String?` — sanitized plain-text body
///   for posts classified as articles (per US-37 / AC-37.2). Nil for
///   recipe rows. Default-nil for every pre-T-640 row, populated only on
///   the next article-fallback `RecipeStore.mergeDetail(_:)` after the
///   user opens an article-classified post.
///
/// **Critically additive:** no field renamed, no field removed, no model
/// added or dropped. The `jsonLDFailedAt` field on `CachedRecipe` keeps
/// its column shape but its semantic shifts (per CL-63 decision 7 — was
/// "row is hidden from lists," now "row is classified as article"). The
/// semantic change is a documentation update only; no on-disk transform
/// is required because the field's nullability state already encodes the
/// new meaning correctly for every pre-T-640 row: rows that pre-T-640 had
/// `jsonLDFailedAt != nil` were truly unrenderable on the first detail
/// open, so on the next pull-to-refresh they re-fetch the post page and
/// the new article-fallback branch either classifies them as articles
/// (the post is a roundup with extractable body — they reappear in the
/// list as articles) or terminates at `.unavailable` (the post page is
/// genuinely broken).
///
/// V3 → V4 is a **lightweight** stage: SwiftData adds the optional column
/// at container open, no transform runs, no data is rewritten. The new
/// column starts as nil on every pre-existing row and stays nil until the
/// view-model's article-classification branch writes it.
public enum SchemaV4: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            CachedRecipe.self,  // same model, new optional column `articleBodyHTML`
            CachedListPage.self,
            CachedImage.self,
            CachedIngredient.self,
            CachedComment.self,
            CachedRating.self,
        ]
    }
}
