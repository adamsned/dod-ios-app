import DODDesignSystem
import DODDomain
import DODFeatureProfile
import DODSupport
import Foundation

extension RecipeDetailViewModel {

    /// DUT-28 / DUT-647 tail — true when the on-form "Display name" passes BOTH
    /// the shared ``GuestIdentitySheet/isValidName(_:)`` shape rule (1–40 chars
    /// trimmed) AND the ``DisplayNameValidator`` content moderation (blank /
    /// vulgar / impersonation blocklist). The guest/comment name path previously
    /// only ran the shape check, so an inappropriate display name that the
    /// profile flow would reject still submitted on a comment. This view model
    /// can see both modules, so it composes them here. Drives the inline field
    /// feedback and (with ``isAuthorEmailValid``) the Submit enablement.
    public var isAuthorNameValid: Bool {
        GuestIdentitySheet.isValidName(commentAuthorName)
            && DisplayNameValidator.validate(commentAuthorName) == .ok
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
        // DUT-605: never allow submit past the character cap. The setter already
        // clamps, so this is belt-and-suspenders against any un-clamped path.
        let withinLimit = commentDraft.count <= RecipeDetailViewModel.commentDraftCharacterLimit
        return (hasRating || hasComment) && isAuthorIdentityValid && withinLimit
    }

    /// True while either the rating or the comment submit is in flight.
    /// Drives the consolidated Submit button's busy label + disabled state.
    public var isSubmittingRatingOrComment: Bool {
        // DUT-602 — the synchronous in-flight guard is folded in so the Submit
        // button disables the instant the combined submit starts, before the
        // first await flips `isSubmittingRating` / `isSubmittingComment`.
        isSubmittingRatingOrCommentInFlight || isSubmittingRating || isSubmittingComment
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
        // DUT-602: synchronous double-submit guard. Set BEFORE the first await
        // (below) so a fast second tap that races in before `isSubmittingRating`
        // / `isSubmittingComment` flip is dropped rather than firing a second
        // POST. `@MainActor` isolation makes the check-and-set atomic. Cleared on
        // every exit via `defer`.
        guard !isSubmittingRatingOrCommentInFlight else { return }

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

        isSubmittingRatingOrCommentInFlight = true
        defer { isSubmittingRatingOrCommentInFlight = false }

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
            var ratingRecorded = false
            if hasRating {
                ratingRecorded = await recordRatingAlongsideComment(stars: pendingUserRating)
            }
            // DUT-395: a failed comment POST preserves the draft (success
            // clears it). Capture the draft state around the call so we can tell
            // the two apart without a separate flag.
            let draftBefore = commentDraft
            await submitComment()
            let commentFailed = !draftBefore.isEmpty && commentDraft == draftBefore
            // DUT-395: when the rating landed but the comment then failed, the
            // rating is silently saved behind a bare comment-error snackbar.
            // Replace it so the user knows their stars stuck and only the
            // comment needs a retry.
            if ratingRecorded, commentFailed {
                snackbarMessage =
                    "Your rating was saved, but the comment didn't post — try again."
            } else if hasRating, !ratingRecorded, !commentFailed {
                // DUT-738: the inverse half-state — the comment posted but the
                // WPRM rating POST failed. The stars are NOT persisted (comment
                // meta doesn't carry them), so the vote is silently lost behind a
                // "Comment posted." confirmation. Tell the user their rating
                // didn't save, mirroring the DUT-395 message above.
                snackbarMessage =
                    "Your comment posted, but your rating didn't save — try the stars again."
            }
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
    ///
    /// DUT-395: returns `true` iff the rating POST succeeded, so the combined
    /// flow can detect a rating-saved-but-comment-failed half-state and message
    /// it (the helper itself stays snackbar-silent).
    @discardableResult
    func recordRatingAlongsideComment(stars: Int) async -> Bool {
        guard (1...5).contains(stars) else { return false }
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty else { return false }
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
            return true
        } catch {
            // Quiet on the SNACKBAR (the comment POST owns the user-facing
            // result), but never a silent DATA loss: the WPRM aggregate POST
            // failed, yet the user did choose a star. DUT-742: persist that
            // vote locally so it survives the revisit + relaunch (and the
            // stars control shows their choice for a one-tap retry) instead of
            // dropping it. The comment's own copy carries the same star via
            // `stampRating` on the optimistic/pending row. Log for the
            // on-device diagnostic trail (DUT-7 parity).
            DODLog.network.error(
                "rating-alongside-comment failed: \(String(describing: error))"
            )
            pendingUserRating = stars
            await persistLocalUserRating(stars)
            return false
        }
    }

    /// DUT-742 — persist THIS device's chosen star locally without touching
    /// the aggregate average/count, preserving whatever cached aggregate we
    /// already trust. Used when the WPRM rating POST fails during a combined
    /// comment+rating submit so the vote isn't lost; the cached `userRating`
    /// re-seeds the stars control on the next open for a one-tap retry.
    func persistLocalUserRating(_ stars: Int) async {
        let base =
            ratingSummary
            ?? RecipeRating(recipeID: listItem.id, average: 0, count: 0, userRating: nil)
        let withVote = RecipeRating(
            recipeID: base.recipeID,
            average: base.average,
            count: base.count,
            userRating: stars
        )
        ratingSummary = withVote
        await dependencies.cacheRatingSummary(withVote)
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
            // DUT-742: stamp the star the user attached onto the optimistic
            // copy. WordPress drops `meta.wprm_comment_rating` on REST comment
            // create and omits it from the public GET, so `posted.ratingValue`
            // is nil — without this stamp the star vanishes from the local +
            // cached (pending) comment even when the WPRM aggregate POST
            // succeeded, and would be lost entirely if it failed.
            let stamped = Self.stampRating(
                Self.stampAuthorEmail(posted, email: trimmedEmail),
                rating: ratingToSend
            )
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

    /// Prepend a freshly-posted comment to the visible list, skipping it if
    /// the same logical comment is already present. DUT-742: match by CONTENT
    /// (or a real shared id) via ``isSameComment(_:_:)`` — not id alone — so a
    /// background refresh that returns the now-approved copy under a different
    /// id than the moderation-time echo doesn't produce a duplicate row. DUT-27.
    func insertPostedCommentIfNew(_ comment: RecipeComment) {
        guard !comments.contains(where: { Self.isSameComment($0, comment) }) else { return }
        comments.insert(comment, at: 0)
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
