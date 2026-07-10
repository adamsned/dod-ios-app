import DODDomain
import DODSupport
import Foundation

// US-13/14/15 — the standalone `submitRating(stars:)` mutation path.
// Extracted from `RecipeDetailViewModel.swift` so that file stays
// under the SwiftLint 400-line `file_length` cap after the Phase c
// (T-741 / CL-138) profile-gate additions.
//
// Pairs with the existing `RecipeDetailViewModel+CommentSubmit.swift`
// extraction — the combined "rate + post comment in one tap" path
// lives there as `submitRatingAndComment()`. This file owns the
// rating-only mutation (the "Submit rating" tap with no comment text).

extension RecipeDetailViewModel {

    /// Submit a star rating using the on-form author identity. DUT-28:
    /// callers validate name + email first (``canSubmitRatingOrComment``)
    /// and persist the identity, so this path trusts the trimmed values it
    /// is handed. AC-13.2 / AC-13.3 / AC-13.5.
    public func submitRating(stars: Int) async {
        guard (1...5).contains(stars) else { return }
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty else {
            snackbarMessage = "Add your name and email to rate this recipe."
            return
        }
        isSubmittingRating = true
        defer { isSubmittingRating = false }

        do {
            let updated = try await dependencies.postRating(
                recipeID: listItem.id,
                stars: stars,
                name: name,
                email: email
            )
            // DUT-305: route the post-success summary through the DUT-216
            // reconciliation instead of assigning/caching it raw. If the
            // client degraded to a zeroed aggregate (its summary GET failed),
            // `applyRatingRefresh` keeps the existing/cached rating rather than
            // blanking the user's just-submitted vote.
            pendingUserRating = stars
            await applyRatingRefresh(updated)
            snackbarMessage = "Thanks for rating."
        } catch {
            DODLog.network.error("post rating failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save your rating. Try again."
        }
    }

    /// DUT-216: reconcile a freshly-fetched rating summary with what's already
    /// on screen / in the cache. The public WPRM aggregate always returns
    /// `userRating == nil`, and `fetchRatingSummary` degrades to a 0/0 summary
    /// on any failure (REG-14) — indistinguishable from a genuinely empty
    /// recipe. So:
    ///   * a real refresh (has ratings) is adopted, but the device's remembered
    ///     vote is carried forward (else "You rated this N stars" is erased on
    ///     every open); and
    ///   * an empty/failed refresh is ignored when a cached aggregate already
    ///     exists (a transient blip must never blank the stars), and is shown
    ///     only on a genuine first load with no cache.
    ///
    /// (`>= 1` rather than `> 0`: `RecipeRating.count` is a rating tally, not a
    /// collection, so SwiftLint's `empty_count` rule doesn't apply here.)
    ///
    /// DUT-545 / DUT-553: a refresh must never *shrink* a good cached aggregate
    /// when — and ONLY when — the incoming refresh is the SYNTHETIC post-submit
    /// fallback. When a rating POST succeeds but its follow-up summary GET
    /// hard-fails, `WPRMRatingsClient.postRating` degrades to a synthetic
    /// aggregate built from the single star we just submitted (DUT-305): it
    /// always has `count == 1` AND a non-nil `userRating` equal to the vote we
    /// just cast (`pendingUserRating`). If we adopted it, a real "4.2★ (500)"
    /// would be overwritten — and CACHED — as "5.0 (1)", persisting across
    /// relaunch.
    ///
    /// DUT-545 originally rejected shrinks by COUNT MAGNITUDE (`fresh.count >=
    /// existingCount`). That over-rejected: a genuine authoritative summary GET
    /// with a smaller-but-correct tally (moderation / spam purge, e.g. 500/4.2 →
    /// 480/4.5) was discarded and the stale aggregate stuck forever (DUT-553).
    /// So distinguish the synthetic fallback EXPLICITLY by its shape instead:
    /// reject a shrink only when the refresh IS that synthetic shape; let a
    /// genuine authoritative GET (`userRating == nil`, any count) update the
    /// aggregate — including DOWNWARD.
    func applyRatingRefresh(_ fresh: RecipeRating) async {
        let existingCount = ratingSummary?.count ?? 0
        // The synthetic post-submit fallback (DUT-305): count == 1 with a
        // non-nil userRating equal to the vote we just cast. This is the ONLY
        // shape allowed to be rejected for shrinking a real aggregate.
        let isSyntheticFallback =
            fresh.count == 1 && fresh.userRating != nil && fresh.userRating == pendingUserRating
        if isSyntheticFallback, fresh.count < existingCount, let existing = ratingSummary {
            // DUT-545: the synthetic fallback must NOT shrink the good aggregate.
            // Keep the existing average/count, but still let the user's own
            // just-submitted vote update. Don't re-cache — the good aggregate
            // already on disk stays authoritative.
            guard let freshVote = fresh.userRating, freshVote != existing.userRating else { return }
            ratingSummary = RecipeRating(
                recipeID: existing.recipeID,
                average: existing.average,
                count: existing.count,
                userRating: freshVote
            )
        } else if fresh.count >= 1 {
            // A real aggregate (authoritative GET, or a real post-submit tally).
            // DUT-553: adopt it even when it shrinks — a genuine moderation/spam
            // purge must self-heal downward.
            let merged = RecipeRating(
                recipeID: fresh.recipeID,
                average: fresh.average,
                count: fresh.count,
                // DUT-350: the just-submitted POST carries the authoritative
                // userRating; the aggregate-GET refresh always returns nil. Prefer
                // `fresh` so re-rating (3★→5★) isn't overwritten by the cached vote
                // — the nil-bearing GET still falls back to the cache.
                userRating: fresh.userRating ?? ratingSummary?.userRating
            )
            ratingSummary = merged
            await dependencies.cacheRatingSummary(merged)
        } else if ratingSummary == nil {
            // First load, no cache, empty-or-failed refresh — show/cache 0/0.
            ratingSummary = fresh
            await dependencies.cacheRatingSummary(fresh)
        }
    }
}
