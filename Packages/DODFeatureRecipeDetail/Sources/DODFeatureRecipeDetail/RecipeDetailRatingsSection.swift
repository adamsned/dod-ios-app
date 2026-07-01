import DODDesignSystem
import DODDomain
import DODFeatureProfile
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
/// **DUT-28 on-form identity.** The display name + email used to live behind
/// a one-time `GuestIdentitySheet` pop-up. A guest identity saved by an
/// earlier build silently satisfied that gate, so the prompt never
/// re-appeared and there was no visible name entry. The name + email now
/// sit directly on this form (``authorFields``), pre-filled from the saved
/// identity, editable inline, validated with the shared
/// `GuestIdentitySheet` validators, and persisted on a valid Submit. The
/// pop-up is retired.
///
/// **Layout note.** Ships as one top-level section; concerns are split into
/// private `@ViewBuilder` properties below so the host drops a single thing
/// onto the scroll content while each piece stays grep-able.
public struct RecipeDetailRatingsSection: View {

    @Bindable public var viewModel: RecipeDetailViewModel

    /// US-44 / CL-138 / DUT-36 Phase c — drives the modal sheet
    /// presentation of ``ProfileEditView`` over the recipe when the
    /// user taps the ``RatingsProfileGate`` CTA. Sheet dismiss
    /// triggers ``RecipeDetailViewModel/refreshProfile()`` via
    /// `.onDisappear`, which reactively flips `hasProfile` and removes
    /// the gate.
    @State private var showProfileSheet: Bool = false

    public init(viewModel: RecipeDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader

            ratingsHeader

            // DUT-24: single rate (stars) + optional comment + Submit
            // surface. DUT-28 adds the on-form name + email above the comment
            // box. Replaces the old separate "Submit rating" bar, the
            // embedded `CommentComposer`, AND the guest-identity pop-up.
            //
            // US-44 / CL-138 / DUT-36 Phase c — wrapped in a ZStack +
            // blur + popup overlay when the user has no profile (see
            // `gatedRateAndReviewCard`). AC-44.11: only this WRITE
            // surface is gated; `commentsList` below stays readable in
            // all states.
            gatedRateAndReviewCard

            Divider()
                .padding(.vertical, DODSpacing.xs)

            commentsList
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.lg)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showProfileSheet) {
            profileEditSheet
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

    /// AC-13.1 / AC-44.14 — aggregate when count ≥ 1; otherwise the
    /// "Be the first to rate this recipe." invitation when comments
    /// are ALSO empty (a recipe with 0 ratings AND ≥1 comments isn't
    /// truly empty — conversation has started, only the aggregate is
    /// missing, so the header collapses to nothing per CL-140).
    /// `summary.count` is a rating-count integer (not a collection
    /// size), so the `empty_count` rule is misfiring — disabled on
    /// this line.
    @ViewBuilder
    private var ratingsHeader: some View {
        if let summary = viewModel.ratingSummary, summary.count > 0 {  // swiftlint:disable:this empty_count
            StarRatingDisplay(average: summary.average, count: summary.count, starSize: 18)
        } else if viewModel.comments.isEmpty {
            Text("Be the first to rate this recipe.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
    }

    // MARK: - GatedRateAndReviewCard (US-44 / CL-138 / DUT-36 Phase c, amended T-747 / CL-144)

    /// AC-44.10 — wraps ``rateAndReviewCard`` in a ZStack with a blur +
    /// ``RatingsProfileGate`` popup when ``RecipeDetailViewModel/hasProfile``
    /// is `false`. Composer is `.disabled` + `.accessibilityHidden`. When
    /// the user has a profile the ZStack collapses to just the composer
    /// (byte-identical to the pre-Phase-c shape). T-747 / CL-144 (DUT-41)
    /// removed the previous `Rectangle().fill(.ultraThinMaterial)` sibling
    /// — its grey-in-dark-mode perimeter framed the popup; the composer's
    /// own blur is sufficient on its own.
    @ViewBuilder
    private var gatedRateAndReviewCard: some View {
        ZStack {
            rateAndReviewCard
                .blur(radius: viewModel.hasProfile ? 0 : 10)
                .disabled(!viewModel.hasProfile)
                .accessibilityHidden(!viewModel.hasProfile)

            if !viewModel.hasProfile {
                RatingsProfileGate {
                    showProfileSheet = true
                }
            }
        }
    }

    /// US-44 / CL-138 / CL-140 — `.sheet(isPresented:)` body. Presents
    /// ``ProfileEditView`` in a `NavigationStack` (back-chevron + Save
    /// toolbar) with `existingProfile: nil` (gate only fires when no
    /// profile exists). `onProfileChanged` + `.onDisappear` both route
    /// through ``refreshProfile()`` — the `@Observable` re-assignment
    /// flips `hasProfile` + reactively removes the gate. T-743's
    /// `.interactiveDismissDisabled(isDirty)` on `ProfileEditView`
    /// prevents swipe-down past unsaved changes. AC-44.10, AC-44.16.
    @ViewBuilder
    private var profileEditSheet: some View {
        NavigationStack {
            profileEditSheetBody
        }
        .onDisappear {
            Task { await viewModel.refreshProfile() }
        }
    }

    /// US-44 / CL-138 — extracted so the `#if canImport(UIKit)` /
    /// `#else` split lives inside a single `@ViewBuilder` rather than
    /// straddling the `NavigationStack { ... }` call boundary. Production
    /// always has a profile store wired (`AppDependencies`'s singleton);
    /// the `else` branch is the test-host / preview fallback.
    @ViewBuilder
    private var profileEditSheetBody: some View {
        if let profileStore = viewModel.profileStoreForGate {
            #if canImport(UIKit)
            ProfileEditView(
                store: profileStore,
                existingProfile: nil,
                onProfileChanged: { [weak viewModel] in
                    await viewModel?.refreshProfile()
                },
                photoStore: viewModel.profilePhotoStoreForGate
            )
            #else
            ProfileEditView(
                store: profileStore,
                existingProfile: nil,
                onProfileChanged: { [weak viewModel] in
                    await viewModel?.refreshProfile()
                }
            )
            #endif
        } else {
            // Test-host / preview fallback — production always wires a
            // store via `AppDependencies`. Surfaces a neutral message
            // instead of a crash if a future test path forgets to set
            // it up.
            Text("Profile setup unavailable.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .padding(DODSpacing.lg)
        }
    }

    // MARK: - RateAndReviewCard

    /// DUT-24 / DUT-28 / DUT-36 Phase d — the single consolidated rate +
    /// optional-comment + Submit surface. AC-13.2 / AC-13.3 (rate the
    /// recipe) and AC-14.3 (optional comment) live in one card with one star
    /// input and one Submit button.
    ///
    /// **CL-139 / DUT-36 Phase d.** The DUT-28 inline "Display name" +
    /// "Email" `authorFields` rows were retired — the user only chooses
    /// stars + types the comment text. Author identity is sourced from
    /// the Profile and displayed above the comment editor as a static
    /// ``PostingAsHeader`` (avatar + name, no input — T-744 / CL-141
    /// (DUT-37) removed the email row). The Phase
    /// c gate guarantees `profile` is non-nil whenever this card is
    /// interactive, so the header always has a profile to render.
    /// AC-44.12.
    private var rateAndReviewCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            postingAsHeader

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

    /// US-44 / CL-139 / DUT-36 Phase d — the static "Posting as <name>"
    /// header that sits above the empty comment editor. Replaces the
    /// retired DUT-28 editable Name + Email `TextField`s. Reads as plain
    /// text ("you're posting as this person"), not as another input. When
    /// the profile is `nil` the header collapses to `EmptyView()` —
    /// although the Phase c gate guarantees the composer is non-
    /// interactive in that state anyway, so this branch is just defensive
    /// (e.g. previews + test hosts that bypass the gate). AC-44.12.
    @ViewBuilder
    private var postingAsHeader: some View {
        if let profile = viewModel.profile {
            #if canImport(UIKit)
            PostingAsHeader(
                profile: profile,
                photoStore: viewModel.profilePhotoStoreForGate
            )
            #else
            PostingAsHeader(profile: profile)
            #endif
        }
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
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
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
    /// user has set a rating OR typed a comment AND the on-form name + email
    /// are valid (DUT-28). One tap persists the identity and posts.
    private var submitButton: some View {
        Button {
            Task { await viewModel.submitRatingAndComment() }
        } label: {
            Text(viewModel.isSubmittingRatingOrComment ? "Submitting…" : "Submit")
                .dodFont(DODType.bodyEmphasized)
                .padding(.horizontal, DODSpacing.lg)
                .padding(.vertical, DODSpacing.sm)
        }
        .dodProminentButton()
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
                    // DUT-392: render threaded — replies nest indented beneath
                    // the comment they answer instead of floating mid-thread.
                    ForEach(CommentThreader.thread(viewModel.comments)) { threaded in
                        commentRow(for: threaded.comment)
                            .padding(.leading, threaded.isReply ? DODSpacing.lg : 0)
                    }
                }
            }
        }
    }

    // CL-139 / Phase d — `commentRow(for:)` + the own-comment avatar
    // override helpers live in ``RecipeDetailRatingsSection+PhaseD.swift``
    // so this struct body stays under the SwiftLint `type_body_length`
    // cap (same extraction pattern as the retired `+AuthorFields.swift`).

    // MARK: - Helpers

    /// Cheap relative-date formatter shared by every row. Uses
    /// `RelativeDateTimeFormatter` so output respects the device locale
    /// (e.g. "il y a 3 jours" on a French locale).
    static func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

// CL-139 / Phase d — ``PostingAsHeader`` struct lives in
// ``RecipeDetailRatingsSection+PhaseD.swift``.
