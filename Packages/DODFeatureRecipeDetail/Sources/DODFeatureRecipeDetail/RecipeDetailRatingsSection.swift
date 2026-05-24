import DODDesignSystem
import DODDomain
import SwiftUI

/// "Ratings & Reviews" section that hangs off the bottom of
/// ``RecipeDetailView``. Composes the existing DesignSystem primitives
/// (``StarRatingDisplay``, ``StarRatingInput``, ``CommentRow``,
/// ``CommentComposer``, ``ModerationBadge``) and the
/// ``RecipeDetailViewModel`` mutation surface added in Wave-2.
///
/// Spec trace: US-13 (AC-13.1, AC-13.2, AC-13.3), US-14 (AC-14.1,
/// AC-14.2, AC-14.3, AC-14.4), US-15 (AC-15.1, AC-15.2).
///
/// **Layout note.** This view ships as one top-level section rather than
/// the four discrete views the task spec named (`RatingsHeader`,
/// `UserRatingBar`, `CommentsList`, `CommentComposerSection`) — they're
/// expressed as private `@ViewBuilder` properties below so the host can
/// drop a single thing onto the scroll content while we still keep each
/// concern visually separated. The naming matches the spec so future
/// readers can `grep` for the named pieces.
public struct RecipeDetailRatingsSection: View {

    @Bindable public var viewModel: RecipeDetailViewModel
    @State private var isGuestSheetPresented: Bool = false
    @State private var guestNameDraft: String = ""
    @State private var guestEmailDraft: String = ""
    /// Tracks which intent triggered the guest-identity sheet so we can
    /// resume the right action once the user finishes the identity flow.
    @State private var pendingIdentityAction: PendingIdentityAction?

    public init(viewModel: RecipeDetailViewModel) {
        self.viewModel = viewModel
    }

    private enum PendingIdentityAction: Equatable {
        case submitRating(Int)
        case submitComment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader

            ratingsHeader

            userRatingBar

            Divider()
                .padding(.vertical, DODSpacing.xs)

            commentsList

            commentComposerSection
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

    // MARK: - UserRatingBar

    /// AC-13.2 / AC-13.3 — interactive 1–5 star input plus a "Submit
    /// rating" button that fires the guest-identity sheet if needed.
    private var userRatingBar: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            if let userRating = viewModel.ratingSummary?.userRating, userRating > 0 {
                Text("You rated this \(userRating) star\(userRating == 1 ? "" : "s")")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            } else {
                Text("Rate this recipe")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            StarRatingInput(
                value: Binding(
                    get: { viewModel.pendingUserRating },
                    set: { viewModel.setPendingRating($0) }
                ),
                starSize: 32,
                isSubmitting: viewModel.isSubmittingRating
            )
            Button {
                triggerSubmitRating()
            } label: {
                Text(viewModel.isSubmittingRating ? "Saving…" : "Submit rating")
                    .dodFont(DODType.bodyEmphasized)
                    .padding(.horizontal, DODSpacing.md)
                    .padding(.vertical, DODSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(DODColor.accent)
            .disabled(viewModel.pendingUserRating == 0 || viewModel.isSubmittingRating)
            .accessibilityLabel("Submit rating")
        }
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
        case .error(let message):
            Text(message)
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

    // MARK: - CommentComposerSection

    /// AC-14.3 — composer bound to `viewModel.commentDraft`; the submit
    /// path runs the guest-identity gate (AC-15.1) before posting.
    private var commentComposerSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text("Write a comment")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            CommentComposer(
                text: Binding(
                    get: { viewModel.commentDraft },
                    set: { viewModel.setCommentDraft($0) }
                ),
                rating: Binding(
                    get: { viewModel.pendingUserRating },
                    set: { viewModel.setPendingRating($0) }
                ),
                isSubmitting: viewModel.isSubmittingComment,
                onSubmit: { triggerSubmitComment() },
                onCancel: { viewModel.setCommentDraft("") }
            )
            .frame(minHeight: 320)
        }
    }

    // MARK: - Guest identity flow

    private func triggerSubmitRating() {
        guard viewModel.pendingUserRating > 0 else { return }
        if viewModel.requiresGuestIdentity {
            pendingIdentityAction = .submitRating(viewModel.pendingUserRating)
            presentGuestSheet()
        } else {
            Task { await viewModel.submitRating(stars: viewModel.pendingUserRating) }
        }
    }

    private func triggerSubmitComment() {
        let trimmed = viewModel.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if viewModel.requiresGuestIdentity {
            pendingIdentityAction = .submitComment
            presentGuestSheet()
        } else {
            Task { await viewModel.submitComment() }
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
        // Resume whichever action originally triggered the sheet — but
        // only if the identity is actually present now (the user may
        // have cancelled).
        guard !viewModel.requiresGuestIdentity, let action = pendingIdentityAction else {
            pendingIdentityAction = nil
            return
        }
        pendingIdentityAction = nil
        switch action {
        case .submitRating(let stars):
            Task { await viewModel.submitRating(stars: stars) }
        case .submitComment:
            Task { await viewModel.submitComment() }
        }
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
