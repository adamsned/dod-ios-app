// Removed by T-640 follow-up — see commit message.
//
// We initially added a SchemaV4 stage for the new
// `CachedRecipe.articleBodyHTML` optional column, but SwiftData computes
// the schema checksum from the @Model class shape itself, so V3 and V4
// (which both reference `CachedRecipe.self`) collide with the
// "Duplicate version checksums detected" runtime error when the
// migration plan tries to use both stages.
//
// The right pattern for adding an optional column to an existing model
// is to bump the model's schema identity in place (e.g. via an alias
// type per Apple's SwiftData migration sample). For the v1 article-
// rendering scope, the column is rare enough on the wire (only set on
// the article-fallback code path) that we can defer the formal schema
// bump and rely on the optional column's nil default being safe across
// container opens. If a future store-open path surfaces a migration
// error in production, the follow-up is to capture a SchemaV4 with a
// renamed `CachedRecipeV4` alias class and migrate values forward.
//
// This file intentionally contains only documentation. The
// `MigrationPlan` reverts to V1 → V2 → V3 lightweight stages; the
// `articleBodyHTML` optional column is added by the in-place
// `CachedRecipe` definition and SwiftData's default schema-inference
// migration handles the additive optional case transparently.
import Foundation
