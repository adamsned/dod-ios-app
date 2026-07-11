import DODDomain
import DODSupport
import Foundation

// US-13/14/15 — the ratings + comments load path. Extracted from
// `RecipeDetailViewModel.swift` so that file stays under the SwiftLint
// 400-line `file_length` cap (same partitioning as `+Fetch` / `+Servings` /
// `+CommentSubmit`).
extension RecipeDetailViewModel {

    /// Populate `ratingSummary` and `comments` from the local cache
    /// immediately for the offline-first read, then refresh from the
    /// network in the background. Network failures leave the cached
    /// state in place per REG-14 / AC-14.6.
    public func loadRatingsAndComments() async {
        // DUT-28: pre-fill the on-form name + email from any saved guest
        // identity so a returning commenter sees their details already
        // populated (and can edit them). No hidden pop-up gate any more.
        await prefillAuthorIdentity()

        commentsLoadState = .loading

        // Step 1: fast path — cached values.
        if let cachedRating = await dependencies.cachedRatingSummary(recipeID: listItem.id) {
            ratingSummary = cachedRating
            // If the cache already remembers this device's userRating,
            // seed the input so the user can "Edit" without retyping.
            if let userRating = cachedRating.userRating, pendingUserRating == 0 {
                pendingUserRating = userRating
            }
        }
        let cachedComments = await dependencies.cachedComments(postID: listItem.id)
        if !cachedComments.isEmpty {
            comments = cachedComments
            commentsLoadState = .ready
        }

        // Step 2: network refresh (best-effort). DUT-216: don't blindly adopt
        // `fresh` — `applyRatingRefresh` carries the remembered userRating
        // forward and never zeros a good cached aggregate on a failure.
        // Bump ``ratingRefreshGeneration`` before the await so a rating
        // submit that lands while this fetch is still in flight is
        // detected as newer on the other side of it, below.
        ratingRefreshGeneration &+= 1
        let ratingGeneration = ratingRefreshGeneration
        let fresh = await dependencies.fetchRatingSummary(recipeID: listItem.id)
        if ratingGeneration == ratingRefreshGeneration {
            await applyRatingRefresh(fresh)
        }

        do {
            let page = try await dependencies.fetchComments(postID: listItem.id, page: 1)
            let approved = page.comments.filter { $0.status == .approved }
            let merged = Self.reconcileComments(approved: approved, cached: cachedComments)
            comments = merged.visible  // DUT-742: keeps own held comment+rating, dedupes on approval
            await dependencies.cacheComments(merged.toCache, postID: listItem.id)
            commentsLoadState = .ready
        } catch {
            DODLog.network.error("comments fetch failed: \(String(describing: error))")
            // If we already hydrated from cache, stay in `.ready` so the
            // user keeps seeing the cached thread (AC-14.6). Only surface
            // `.error` when we have nothing to show.
            if comments.isEmpty {
                commentsLoadState = .error("Couldn't load comments.")
            }
        }
    }
}
