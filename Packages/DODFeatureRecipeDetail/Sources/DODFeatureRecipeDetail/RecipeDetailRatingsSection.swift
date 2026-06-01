import DODDesignSystem
import DODDomain
import SwiftUI

/// "Ratings & Reviews" section that hangs off the bottom of
/// ``RecipeDetailView``. Composes the existing DesignSystem primitives
/// (``StarRatingDisplay``, ``StarRatingInput``, ``CommentRow``,
/// ``ModerationBadge``) and the ``RecipeDetailViewModel`` mutation surface.
///
/// Spec trace: US-13 (AC-13.1, AC-13.2, AC-13.3), US-14 (AC-14.1,
/// AC-14.2, AC-14.3, AC-14.4), US-15 (AC-15.1, AC-15.2). DUT-24.
///
/// **DUT-24 consolidation.** The pre-DUT-24 layout shipped TWO interactive
/// star controls bound to the same `pendingUserRating` — a standalone
/// "Submit rating" star bar AND a `CommentComposer` that rendered its own
/// "Rate (optional)" star input plus its own Submit button. Testers saw the
/// rating doubled. This section now exposes ONE rate-and-review surface:
/// a single ``StarRatingInput`` + an optional inline comment editor + a
/// single Submit button (``rateAndReviewCard``). The aggregate
/// ``StarRatingDisplay`` above it is read-only (a number, not a second
/// control). The comments-load *error* is no longer surfaced inline here
/// (it leaked "Couldn't load comments." into the review area) — the
/// load-failed state degrades to the same neutral empty copy.
///
/// **Layout note.** Ships as one top-level section; concerns are split into
/// private `@ViewBuilder` properties below so the host drops a single thing
/// onto the scroll content while each piece stays grep-able.
public struct RecipeDetailRatingsSection: View {

    @Bindable public var viewModel: RecipeDetailViewModel
    @State private var isGuestSheetPresented: Bool = false
    @State private var guestNameDraft: String = ""
    @State private var guestEmailDraft: String = ""
    /// True when the user tapped Submit but had to clear the guest-identity
    /// gate first — we resume the consolidated submit once the sheet
    /// dismisses with an identity in place. DUT-24 collapsed the previous
    /// per-action enum (rate vs comment) into this single flag because the
    /// section now has one Submit path.
    @State private var pendingSubmitAfterIdentity: Bool = false

    public init(viewModel: RecipeDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader

            ratingsHeader

            // DUT-24: single rate (stars) + optional comment + Submit
            // surface. Replaces the old separate "Submit rating" bar and the
            // embedded `CommentComposer` (which each carried their own star
            // input, doubling the rating control).
            rateAndReviewCard

            Divider()
                .padding(.vertical, DODSpacing.xs)

            commentsList
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.lg)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isGuestSheetPresented, onDismiss: handleGuestSheetDismiss) {
            GuestIdentitySheet(
                displayName: $guestNameDraft,
                email: $guestEmailDraft,
                isSubmitting: false,
                onContinue: {
                    Task { await handleGuestContinue() }
                }
            )
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
    }

    // MARK: - Section header

    private var sectionHeader: some View {
        Text("Ratings & Reviews")
            .dodFont(DODType.heading)
            .foregroundStyle(DODColor.label)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - RatingsHeader

    /// AC-13.1 — shows the aggregate when count ≥ 1, otherwise the
    /// "Be the first to rate this recipe." invitation. `summary.count`
    /// here is the rating-count integer (not a collection size), so the
    /// `empty_count` rule is misfiring — disabled on this line.
    @ViewBuilder
    private var ratingsHeader: some View {
        if let summary = viewModel.ratingSummary, summary.count > 0 {  // swiftlint:disable:this empty_count
            StarRatingDisplay(average: summary.average, count: summary.count, starSize: 18)
        } else {
            Text("Be the first to rate this recipe.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
    }

    // MARK: - RateAndReviewCard

    /// DUT-24 — the single consolidated rate + optional-comment + Submit
    /// surface. AC-13.2 / AC-13.3 (rate the recipe) and AC-14.3 (optional
    /// comment) now live in one card with one star input and one Submit
    /// button. Submit routes through the guest-identity gate when needed.
    private var rateAndReviewCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            ratingPrompt

            StarRatingInput(
                value: Binding(
                    get: { viewModel.pendingUserRating },
                    set: { viewModel.setPendingRating($0) }
                ),
                starSize: 32,
                isSubmitting: viewModel.isSubmittingRatingOrComment
            )

            commentField

            submitButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rate and review this recipe")
    }

    /// Caption above the stars: reflects the user's prior rating if the
    /// cache remembers one, otherwise the "Rate this recipe" invitation.
    @ViewBuilder
    private var ratingPrompt: some View {
        if let userRating = viewModel.ratingSummary?.userRating, userRating > 0 {
            Text("You rated this \(userRating) star\(userRating == 1 ? "" : "s")")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        } else {
            Text("Rate this recipe")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
    }

    /// Optional inline comment editor (AC-14.3). Empty is valid — the user
    /// can submit a star rating alone. Styling matches the DesignSystem
    /// `CommentComposer` editor (bordered `TextEditor` + placeholder) so the
    /// look is unchanged from the old composer, minus its duplicate stars.
    private var commentField: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Add a comment (optional)")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                    .stroke(DODColor.labelSecondary.opacity(0.25), lineWidth: 1)

                TextEditor(
                    text: Binding(
                        get: { viewModel.commentDraft },
                        set: { viewModel.setCommentDraft($0) }
                    )
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .scrollContentBackground(.hidden)
                .padding(DODSpacing.xs)
                .frame(minHeight: 120)
                .disabled(viewModel.isSubmittingRatingOrComment)
                .accessibilityLabel("Comment (optional)")

                if viewModel.commentDraft.isEmpty {
                    Text("Share your tips, substitutions, or thoughts.")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary.opacity(0.7))
                        .padding(.horizontal, DODSpacing.sm)
                        .padding(.vertical, DODSpacing.sm + 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// The one and only Submit control for the section. Enabled when the
    /// user has set a rating OR typed a comment; routes through the
    /// guest-identity sheet on first submit.
    private var submitButton: some View {
        Button {
            triggerSubmit()
        } label: {
            Text(viewModel.isSubmittingRatingOrComment ? "Submitting…" : "Submit")
                .dodFont(DODType.bodyEmphasized)
                .padding(.horizontal, DODSpacing.lg)
                .padding(.vertical, DODSpacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(DODColor.accent)
        .disabled(!viewModel.canSubmitRatingOrComment || viewModel.isSubmittingRatingOrComment)
        .accessibilityLabel("Submit rating and review")
    }

    // MARK: - CommentsList

    /// AC-14.1 / AC-14.2 — iterates `viewModel.comments`. The view model
    /// already filters out non-approved rows from the public list, but
    /// the `ModerationBadge` still renders on any non-`.approved` row in
    /// case the cache layer surfaces pending-from-this-device rows later
    /// (sub 3 plumbing).
    @ViewBuilder
    private var commentsList: some View {
        switch viewModel.commentsLoadState {
        case .idle, .loading:
            HStack {
                ProgressView()
                Text("Loading comments…")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        case .error:
            // DUT-24: do NOT surface the comments-load failure ("Couldn't
            // load comments.") in the review area — testers flagged that
            // raw error string leaking into the UI. Degrade gracefully to
            // the same neutral copy as an empty thread; the rate + review
            // surface above stays fully usable regardless.
            Text("No comments yet. Be the first to share your tips.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        case .ready:
            if viewModel.comments.isEmpty {
                Text("No comments yet. Be the first to share your tips.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: DODSpacing.md) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(
                            authorName: displayAuthor(for: comment),
                            avatarURL: comment.avatarURL,
                            relativeDate: Self.relativeDateString(comment.dateGMT),
                            bodyText: comment.body,
                            ratingValue: comment.ratingValue,
                            isPendingModeration: comment.status != .approved
                        )
                    }
                }
            }
        }
    }

    // MARK: - Guest identity flow

    /// DUT-24 — single submit path for the consolidated card. Fires the
    /// guest-identity sheet (AC-15.1) on first submit, then routes to the
    /// view model's ``RecipeDetailViewModel/submitRatingAndComment()`` which
    /// picks the right underlying network call (comment-with-rating, or
    /// rating-only) without doubling any UI.
    private func triggerSubmit() {
        guard viewModel.canSubmitRatingOrComment else { return }
        if viewModel.requiresGuestIdentity {
            pendingSubmitAfterIdentity = true
            presentGuestSheet()
        } else {
            Task { await viewModel.submitRatingAndComment() }
        }
    }

    private func presentGuestSheet() {
        // Seed the fields from any prior entry the user typed before
        // dismissing — `@State` already preserves these across re-opens.
        isGuestSheetPresented = true
    }

    @MainActor
    private func handleGuestContinue() async {
        await viewModel.saveGuestIdentityAndContinue(
            name: guestNameDraft,
            email: guestEmailDraft
        )
        isGuestSheetPresented = false
    }

    private func handleGuestSheetDismiss() {
        // Resume the consolidated submit only if the identity is actually
        // present now (the user may have cancelled the sheet).
        guard pendingSubmitAfterIdentity, !viewModel.requiresGuestIdentity else {
            pendingSubmitAfterIdentity = false
            return
        }
        pendingSubmitAfterIdentity = false
        Task { await viewModel.submitRatingAndComment() }
    }

    // MARK: - Helpers

    private func displayAuthor(for comment: RecipeComment) -> String {
        let trimmed = comment.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anonymous" : trimmed
    }

    /// Cheap relative-date formatter shared by every row. Uses
    /// `RelativeDateTimeFormatter` so output respects the device locale
    /// (e.g. "il y a 3 jours" on a French locale).
    static func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
