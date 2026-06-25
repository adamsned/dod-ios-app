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
}
