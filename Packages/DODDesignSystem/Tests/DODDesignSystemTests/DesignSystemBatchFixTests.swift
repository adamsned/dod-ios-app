import SwiftUI
import Testing

@testable import DODDesignSystem

/// Unit tests for the DUT-646 / 659 / 605 batch. Split out from
/// `ComponentsTests` to keep both files under SwiftLint's file/type-body caps.
@Suite("DesignSystem batch fixes (DUT-646, 659, 605)") struct DesignSystemBatchFixTests {

    // MARK: - DUT-659 — Snackbar restart on identical-text re-presentation

    /// The `.task(id:)` key must distinguish two presentations that share
    /// IDENTICAL text but differ by `presentationToken`, so re-showing the same
    /// message restarts the auto-dismiss countdown instead of inheriting the
    /// previous presentation's remaining time.
    @Test func snackbarDismissKeyRestartsOnIdenticalMessageWhenTokenBumps() {
        let first = Snackbar.DismissKey(token: 0, message: "Saved.")
        let sameTextNewToken = Snackbar.DismissKey(token: 1, message: "Saved.")
        let sameTextSameToken = Snackbar.DismissKey(token: 0, message: "Saved.")
        // Identical text but a bumped token ⇒ a DIFFERENT key ⇒ `.task` restarts.
        #expect(first != sameTextNewToken)
        // Identical text + identical token ⇒ same key ⇒ countdown is preserved.
        #expect(first == sameTextSameToken)
        // A genuine text change also restarts, even without a token bump.
        #expect(first != Snackbar.DismissKey(token: 0, message: "Removed."))
    }

    /// The default `presentationToken` is `0`, preserving the single-shot host
    /// behavior (restart only on a real text change).
    @Test func snackbarDefaultsPresentationTokenToZero() {
        let plain = Snackbar(message: "Saved.")
        #expect(plain.presentationToken == 0)
    }

    // MARK: - DUT-646 — StarRatingDisplay count-caption suppression

    /// `StarRatingDisplay` defaults to showing the count caption but suppresses
    /// it when `showsCount: false` (the per-comment star line).
    @Test func starRatingDisplayShowsCountFlagDefaultsTrueAndCanSuppress() {
        let aggregate = StarRatingDisplay(average: 4.5, count: 27)
        #expect(aggregate.showsCount)
        let perComment = StarRatingDisplay(average: 5, count: 1, starSize: 12, showsCount: false)
        #expect(!perComment.showsCount)
    }

    // MARK: - DUT-605 — CommentComposer character cap

    /// The cap is enforced on submit: a body at/under `maxCharacters` (with the
    /// other conditions met) can submit; one over the cap cannot.
    @Test func commentComposerCanSubmitRespectsCharacterCap() {
        let cap = 10
        // At the cap → allowed.
        #expect(
            CommentComposer.canSubmit(
                text: String(repeating: "a", count: cap),
                rating: 0,
                maxCharacters: cap,
                isSubmitting: false
            )
        )
        // One over the cap → blocked, even though it has a body.
        #expect(
            !CommentComposer.canSubmit(
                text: String(repeating: "a", count: cap + 1),
                rating: 0,
                maxCharacters: cap,
                isSubmitting: false
            )
        )
        // Over the cap stays blocked even with a rating present.
        #expect(
            !CommentComposer.canSubmit(
                text: String(repeating: "a", count: cap + 1),
                rating: 5,
                maxCharacters: cap,
                isSubmitting: false
            )
        )
    }

    /// The pre-existing enablement contract is preserved: empty+unrated is
    /// blocked, a rating alone qualifies, and in-flight is always blocked.
    @Test func commentComposerCanSubmitPreservesBaseContract() {
        #expect(!CommentComposer.canSubmit(text: "   ", rating: 0, maxCharacters: 1000, isSubmitting: false))
        #expect(CommentComposer.canSubmit(text: "", rating: 4, maxCharacters: 1000, isSubmitting: false))
        #expect(CommentComposer.canSubmit(text: "Nice!", rating: 0, maxCharacters: 1000, isSubmitting: false))
        #expect(!CommentComposer.canSubmit(text: "Nice!", rating: 5, maxCharacters: 1000, isSubmitting: true))
    }
}
