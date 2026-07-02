import DODDesignSystem
import DODDomain
import DODSupport
import Foundation

extension RecipeDetailViewModel {

    /// DUT-28 — true when the on-form "Display name" passes the shared
    /// ``GuestIdentitySheet/isValidName(_:)`` rule (1–40 chars trimmed).
    /// Drives the inline field feedback and (with ``isAuthorEmailValid``)
    /// the Submit enablement.
    public var isAuthorNameValid: Bool {
        GuestIdentitySheet.isValidName(commentAuthorName)
    }

    /// DUT-28 — true when the on-form "Email" passes the shared
    /// ``GuestIdentitySheet/isValidEmail(_:)`` structural rule.
    public var isAuthorEmailValid: Bool {
        GuestIdentitySheet.isValidEmail(commentAuthorEmail)
    }

    /// DUT-28 — both author fields are present and well-formed. The single
    /// Submit button additionally requires this so we never fire a POST with
    /// a blank / malformed author (WP 400s `author_email=""`).
    public var isAuthorIdentityValid: Bool {
        isAuthorNameValid && isAuthorEmailValid
    }

    /// True when the consolidated rate + review surface has something to
    /// submit — either a star selection OR a non-blank comment draft — AND
    /// the on-form author identity is valid (DUT-28). The single Submit
    /// button binds its disabled-state to this so the user can rate,
    /// comment, or do both from one control, but only once they've supplied
    /// a usable name + email.
    public var canSubmitRatingOrComment: Bool {
        let hasRating = pendingUserRating > 0
        let hasComment =
            !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasRating || hasComment) && isAuthorIdentityValid
    }

    /// True while either the rating or the comment submit is in flight.
    /// Drives the consolidated Submit button's busy label + disabled state.
    public var isSubmittingRatingOrComment: Bool {
        isSubmittingRating || isSubmittingComment
    }

    /// DUT-24 / DUT-28 / DUT-31: single entry point for the consolidated
    /// "name + email + rate (stars) + optional comment + Submit" surface.
    /// Validates the on-form author identity, persists it, then routes to the
    /// existing network methods so the rating/comment POST logic stays owned
    /// by its current paths (presentation-layer orchestration only):
    ///
    /// * comment **and** stars → record the rating via the proven WPRM path
    ///   (``recordRatingAlongsideComment(stars:)``) **and** post the comment
    ///   (``submitComment()``). DUT-31: the comment meta alone does NOT land
    ///   the rating (WordPress drops `meta.wprm_comment_rating` on REST
    ///   comment create — it is not registered for writes), so the rating has
    ///   to go through `wp-recipe-maker/v1/rating` — the same mechanism the
    ///   rating-only path already uses successfully — or it is silently lost.
    /// * a non-blank comment, no stars → ``submitComment()`` only.
    /// * stars only (no comment) → ``submitRating(stars:)``.
    ///
    /// DUT-28: the name + email now live on the form (no pop-up). An invalid
    /// identity blocks the submit with inline feedback rather than firing a
    /// doomed POST; a valid identity is persisted to the Keychain so the
    /// next visit pre-fills it.
    public func submitRatingAndComment() async {
        let hasComment =
            !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRating = pendingUserRating > 0
        guard hasComment || hasRating else { return }

        // DUT-28: block a doomed POST when the on-form identity is invalid;
        // the view shows the inline field feedback, this surfaces a snackbar.
        guard isAuthorIdentityValid else {
            snackbarMessage = "Add your name and a valid email to submit."
            return
        }

        // Persist the entered identity before posting so a returning
        // commenter is pre-filled next time. Best-effort — never blocks the
        // POST (see ``persistAuthorIdentity(name:email:)``).
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        await persistAuthorIdentity(name: name, email: email)

        if hasComment {
            // DUT-31: when the user rated AND commented, record the rating via
            // the WPRM endpoint FIRST (the comment meta won't carry it), then
            // post the comment so the comment's snackbar is the final, primary
            // confirmation the user sees. The rating step is quiet on its own —
            // it never overwrites the comment's success/failure message.
            if hasRating {
                await recordRatingAlongsideComment(stars: pendingUserRating)
            }
            await submitComment()
        } else {
            await submitRating(stars: pendingUserRating)
        }
    }

    /// DUT-31: record the star rating through the proven WPRM path
    /// (`wp-recipe-maker/v1/rating`, the same call ``submitRating(stars:)``
    /// makes) as part of a combined comment **+** rating submit, WITHOUT
    /// touching the snackbar.
    ///
    /// Why a separate, quiet helper instead of reusing ``submitRating(stars:)``
    /// here: in the combined flow the comment is the user's primary action and
    /// owns the snackbar ("Comment posted." / "…after approval." / an error).
    /// ``submitRating(stars:)`` would clobber that with "Thanks for rating.",
    /// and a rating hiccup must not surface a scary "Couldn't save your
    /// rating" when the comment itself succeeded. So this path updates the
    /// summary + caches the new aggregate on success and only LOGS on failure
    /// — the comment, which lands on its own POST, is unaffected either way.
    func recordRatingAlongsideComment(stars: Int) async {
        guard (1...5).contains(stars) else { return }
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty else { return }
        do {
            let updated = try await dependencies.postRating(
                recipeID: listItem.id,
                stars: stars,
                name: name,
                email: email
            )
            // DUT-305: reconcile through `applyRatingRefresh` (DUT-216) rather
            // than assigning/caching the summary raw, so a degraded 0/0
            // aggregate (the client's summary GET failed after a successful
            // POST) never blanks the user's just-submitted vote.
            pendingUserRating = stars
            await applyRatingRefresh(updated)
        } catch {
            // Quiet on failure: the comment POST owns the user-facing result,
            // and the rating can be re-submitted from the stars control. Log
            // for the on-device diagnostic trail (DUT-7 parity).
            DODLog.network.error(
                "rating-alongside-comment failed: \(String(describing: error))"
            )
        }
    }

    /// Submit the in-progress comment draft (and the pending rating, if
    /// non-zero), using the on-form author identity (DUT-28). AC-14.3 /
    /// AC-14.4 / AC-14.7.
    ///
    /// Extracted from `RecipeDetailViewModel.swift` (DUT-7) so the parent
    /// file stays under the SwiftLint `file_length` cap of 400 lines after
    /// the author-identity guard landed.
    public func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // DUT-28: the author name + email come from the on-form fields, not a
        // pop-up. Posting a blank `author_email` yields WP 400 and the comment
        // silently never lands, so block on an invalid/empty identity and tell
        // the user why instead of firing a doomed POST (the DUT-7 guard, now
        // sourced from the form).
        let trimmedName = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty else {
            DODLog.network.error("comment submit blocked: empty author name/email")
            snackbarMessage = "Add your name and email to post a comment."
            return
        }
        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let ratingToSend = pendingUserRating > 0 ? pendingUserRating : nil
            let posted = try await dependencies.postComment(
                postID: listItem.id,
                body: trimmed,
                name: trimmedName,
                email: trimmedEmail,
                rating: ratingToSend
            )
            // CL-139 / Phase d: stamp the just-posted comment's
            // `authorEmail` with the value we sent so own-comment row
            // rendering can match against the current profile's email
            // case-insensitively. WordPress's GET response doesn't
            // include `author_email`, so the local stamp is the only
            // way the row picks up the profile photo in-session.
            let stamped = Self.stampAuthorEmail(posted, email: trimmedEmail)
            let awaitingApproval = stamped.status != .approved
            if !awaitingApproval {
                // Prepend the approved comment so the user sees it land.
                insertPostedCommentIfNew(stamped)
                await dependencies.cacheComments(comments, postID: listItem.id)
                snackbarMessage = "Comment posted."
            } else {
                // DUT-27: WordPress holds new comments for moderation, so the
                // returned comment has a pending/hold status and the
                // approved-comments GET will NOT return it on refresh. The
                // priority is that the user clearly knows the post SUCCEEDED so
                // they do not re-submit (the build-8 duplicate loop). Show a
                // prominent positive confirmation AND optimistically insert the
                // just-posted comment locally — `CommentRow` renders any
                // non-approved status with the "Awaiting approval" badge
                // (US-15), so the user sees their words on screen immediately.
                insertPostedCommentIfNew(stamped)
                // DUT-387: persist the held comment into the PENDING bucket, not
                // as a normal public row. Caching it via `cacheComments` marks it
                // `isPendingFromThisDevice: false`, so it rendered as a normal
                // approved comment on every cold/offline open and — if WP later
                // rejects it — stuck forever. The pending bucket is filtered from
                // the public reader and flips to approved when a fetch returns it.
                await dependencies.cachePendingComment(stamped, postID: listItem.id)
                snackbarMessage = "Comment submitted — it will appear after approval."
            }
            commentDraft = ""
        } catch {
            DODLog.network.error("post comment failed: \(String(describing: error))")
            snackbarMessage = Self.commentErrorSnackbar(for: error)
        }
    }

    /// Prepend a freshly-posted comment to the visible list, skipping it if a
    /// comment with the same WP id is already present. Guarding on id keeps
    /// the `ForEach` (keyed by `RecipeComment.id`) free of duplicate-key
    /// glitches if a submit is somehow retried, and avoids a double row when a
    /// later refresh returns the now-approved comment. DUT-27.
    func insertPostedCommentIfNew(_ comment: RecipeComment) {
        guard !comments.contains(where: { $0.id == comment.id }) else { return }
        comments.insert(comment, at: 0)
    }

    /// DUT-433 — the cached comments this device is still waiting on. The
    /// public comments GET never returns `hold` rows, so a refresh that
    /// adopted the fetched page verbatim wiped the author's own
    /// awaiting-approval comment from the thread on every online re-open —
    /// recreating the build-8 "did my comment post?" re-submit loop DUT-27 /
    /// DUT-387 exist to prevent. Pending rows come back from the cache with a
    /// non-approved status; keep the ones the fresh page didn't supersede.
    static func stillPendingComments(
        in cached: [RecipeComment],
        approved: [RecipeComment]
    ) -> [RecipeComment] {
        let approvedIDs = Set(approved.map(\.id))
        return cached.filter { $0.status != .approved && !approvedIDs.contains($0.id) }
    }

    /// CL-139 / DUT-36 Phase d — return a copy of the just-posted
    /// comment with its `authorEmail` field set to the value we sent on
    /// the wire. WordPress's public `/wp/v2/comments` GET response does
    /// NOT include `author_email` (privacy — moderation-only field), so
    /// the wire-format `WPDTO.Comment.toDomain()` maps `authorEmail`
    /// to `""`. This helper rewrites that field on the returned domain
    /// model so own-comment row rendering can match the current
    /// profile's email case-insensitively and swap in
    /// ``ProfilePhotoView``. AC-44.13.
    static func stampAuthorEmail(_ comment: RecipeComment, email: String) -> RecipeComment {
        RecipeComment(
            id: comment.id,
            postID: comment.postID,
            parentID: comment.parentID,
            authorName: comment.authorName,
            authorEmail: email,
            avatarURL: comment.avatarURL,
            dateGMT: comment.dateGMT,
            body: comment.body,
            ratingValue: comment.ratingValue,
            status: comment.status
        )
    }
}
