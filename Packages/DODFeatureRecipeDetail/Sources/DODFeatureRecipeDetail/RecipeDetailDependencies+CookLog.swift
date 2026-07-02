import DODPersistence
import DODSupport
import Foundation

/// DUT-326 — live Cooking Journal wiring for ``LiveRecipeDetailDependencies``.
///
/// Extracted from `RecipeDetailDependencies.swift` so that file stays under the
/// SwiftLint `file_length` cap (same split pattern as the `+Download` /
/// `+CommentsRatings` / `+Profile` extensions). Routes the Cook Mode "Add to
/// Cooking Journal" action straight to ``RecipeStore/logCook(_:)`` — the same
/// store + value type the Feed package's journal uses, so a cook logged from
/// Cook Mode shows up in the journal and counts toward rank.
extension LiveRecipeDetailDependencies {

    public func logCook(_ entry: CookLogEntry) async throws {
        try await store.logCook(entry)
    }

    public func deleteCookPhoto(id: String) async {
        // DUT-208 — mirrors the DUT-423 dedup-branch cleanup in
        // RecipeStore+CookLog: the photo was persisted before the failed
        // `logCook`, so delete it here rather than orphan it.
        CookPhotoStore().delete(id: id)
    }
}
