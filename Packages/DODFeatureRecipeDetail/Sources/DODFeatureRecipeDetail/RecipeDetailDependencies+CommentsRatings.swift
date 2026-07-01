import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

// US-13/14/15 — live ``RecipeDetailDependencies`` impls for the WPRM
// ratings + WP comments seams. Extracted from
// `RecipeDetailDependencies.swift` so that file stays under the
// SwiftLint 400-line `file_length` cap after the Phase c (T-741 /
// CL-138) profile-gate additions.

extension LiveRecipeDetailDependencies {

    public func fetchRatingSummary(recipeID: Int) async -> RecipeRating {
        // REG-14: never throw — degrade to a zero-valued summary on any
        // failure. The underlying client already handles 401/403/offline
        // that way; this wrapper catches anything that slips past
        // (timeouts, 5xx, decoding hiccups WPRMRatingsClient surfaces).
        do {
            return try await ratingsClient.summary(forRecipeID: recipeID)
        } catch {
            DODLog.network.error("rating summary fetch failed: \(String(describing: error))")
            return RecipeRating(recipeID: recipeID, average: 0, count: 0, userRating: nil)
        }
    }

    public func cachedRatingSummary(recipeID: Int) async -> RecipeRating? {
        do {
            guard let snapshot = try await store.cachedRating(forRecipeID: recipeID) else {
                return nil
            }
            return RecipeRating(
                recipeID: snapshot.recipeID,
                average: snapshot.average,
                count: snapshot.count,
                userRating: snapshot.userRating
            )
        } catch {
            DODLog.persistence.error("cached rating read failed: \(String(describing: error))")
            return nil
        }
    }

    public func cacheRatingSummary(_ summary: RecipeRating) async {
        let snapshot = CachedRatingSnapshot(
            recipeID: summary.recipeID,
            average: summary.average,
            count: summary.count,
            userRating: summary.userRating
        )
        do {
            try await store.cacheRating(snapshot)
        } catch {
            DODLog.persistence.error("cache rating failed: \(String(describing: error))")
        }
    }

    public func postRating(
        recipeID: Int,
        stars: Int,
        name: String,
        email: String
    ) async throws -> RecipeRating {
        let updated = try await ratingsClient.postRating(
            recipeID: recipeID,
            stars: stars,
            authorName: name,
            authorEmail: email
        )
        // Telemetry only AFTER the network call returns successfully (per
        // task spec) — and never carries name/email (AC-15.4).
        await sendTelemetry(.recipeRated(recipeID: recipeID, stars: stars))
        return updated
    }

    public func fetchComments(
        postID: Int,
        page: Int
    ) async throws -> WPCommentsClient.CommentsPage {
        try await commentsClient.comments(forPostID: postID, page: page)
    }

    public func cachedComments(postID: Int) async -> [RecipeComment] {
        do {
            let snapshots = try await store.cachedComments(forPostID: postID)
            return snapshots.map(Self.snapshotToComment)
        } catch {
            DODLog.persistence.error("cached comments read failed: \(String(describing: error))")
            return []
        }
    }

    public func cacheComments(_ comments: [RecipeComment], postID: Int) async {
        let snapshots = comments.map { Self.commentToSnapshot($0, postID: postID) }
        do {
            try await store.cacheComments(snapshots)
        } catch {
            DODLog.persistence.error("cache comments failed: \(String(describing: error))")
        }
    }

    public func cachePendingComment(_ comment: RecipeComment, postID: Int) async {
        // DUT-387 — route to the pending bucket; `upsertPendingComment` sets
        // `isPendingFromThisDevice = true` (the snapshot's default `false` is
        // overridden), so a held comment is filtered from public reader UI and
        // flips to approved when a later fetch returns it.
        do {
            try await store.upsertPendingComment(Self.commentToSnapshot(comment, postID: postID))
        } catch {
            DODLog.persistence.error("cache pending comment failed: \(String(describing: error))")
        }
    }

    public func postComment(
        postID: Int,
        body: String,
        name: String,
        email: String,
        rating: Int?
    ) async throws -> RecipeComment {
        let posted = try await commentsClient.postComment(
            postID: postID,
            authorName: name,
            authorEmail: email,
            content: body,
            ratingValue: rating
        )
        // Telemetry only AFTER the network call returns. `awaitingApproval`
        // mirrors WP's `hold` (or anything not explicitly `approved`).
        await sendTelemetry(
            .recipeCommentSubmitted(
                recipeID: postID,
                awaitingApproval: posted.status != .approved
            )
        )
        return posted
    }

    public func loadGuestIdentity() async -> (name: String, email: String)? {
        do {
            guard let identity = try guestIdentity.load() else { return nil }
            return (name: identity.displayName, email: identity.email)
        } catch {
            DODLog.persistence.error("guest identity load failed: \(String(describing: error))")
            return nil
        }
    }

    public func saveGuestIdentity(name: String, email: String) async throws {
        try guestIdentity.save(GuestIdentity(displayName: name, email: email))
    }
}
