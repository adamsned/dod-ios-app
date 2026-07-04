import DODDesignSystem
import DODDomain
import DODFeatureProfile
import SwiftUI

// US-44 / CL-139 / DUT-36 Phase d — Composer auto-fill + own-comment
// profile photo surface for ``RecipeDetailRatingsSection``. Extracted
// from the section's main file so it stays under the SwiftLint
// `file_length` + `type_body_length` caps after Phase d's additions
// (same extraction pattern as the retired Phase a `+AuthorFields.swift`).
//
// What lives here:
// - ``PostingAsHeader`` — the static "Posting as <name>" sub-view that
//   sits above the empty comment editor (AC-44.12).
// - ``RecipeDetailRatingsSection/commentRow(for:)`` — the per-comment
//   row builder that swaps in ``ProfilePhotoView`` for the current
//   user's own comments via the case-insensitive email match (AC-44.13).
// - The supporting ``ownCommentAvatarOverride(for:)`` /
//   ``ownCommentAvatarView(profile:)`` helpers.
//
// Spec trace: US-44 AC-44.12, AC-44.13; CL-139.

extension RecipeDetailRatingsSection {

    /// US-44 / CL-139 / DUT-36 Phase d — render one comment row, swapping
    /// the AsyncImage / Gravatar avatar for ``ProfilePhotoView`` when the
    /// comment's ``RecipeComment/authorEmail`` case-insensitively matches
    /// the current profile's email. Other users' comments fall through to
    /// the existing avatar path. Old guest-attributed comments (whose
    /// empty `authorEmail` doesn't match any real profile email) also
    /// fall through — AC-44.7 preserved by construction. AC-44.13.
    @ViewBuilder
    func commentRow(for comment: RecipeComment) -> some View {
        CommentRow(
            authorName: displayAuthor(for: comment),
            avatarURL: comment.avatarURL,
            relativeDate: Self.relativeDateString(comment.dateGMT),
            bodyText: comment.body,
            ratingValue: comment.ratingValue,
            isPendingModeration: comment.status != .approved,
            avatarOverride: ownCommentAvatarOverride(for: comment)
        )
        // DUT-501 (Guideline 1.2) — report/block another user's comment. Report
        // hides it locally at once and opens a prefilled moderation email;
        // Block hides every comment from that author, app-wide.
        .contextMenu {
            if viewModel.canModerate(comment) {
                Button {
                    reportAndOpenMail(for: comment)
                } label: {
                    Label("Report Comment", systemImage: "flag")
                }
                Button(role: .destructive) {
                    viewModel.blockAuthor(of: comment)
                } label: {
                    Label(blockLabel(for: comment), systemImage: "hand.raised")
                }
            }
        }
    }

    /// DUT-546 gap 2 — report the comment (hide it locally), then open the
    /// prefilled moderation `mailto:` and check the open outcome. On a device
    /// with no mail account `openURL`'s completion reports `accepted == false`;
    /// we route that back through the view model so it surfaces the published
    /// contact address as a fallback instead of leaving the user believing the
    /// report was sent. If the URL couldn't even be built we treat it as a
    /// failed send for the same reason.
    func reportAndOpenMail(for comment: RecipeComment) {
        viewModel.reportComment(comment)
        guard let url = viewModel.reportMailtoURL(for: comment) else {
            viewModel.acknowledgeReport(of: comment, mailtoOpened: false)
            return
        }
        openURL(url) { accepted in
            viewModel.acknowledgeReport(of: comment, mailtoOpened: accepted)
        }
    }

    /// DUT-546 gap 1 — a blank-name (Anonymous) row can't be name-blocked, so
    /// the destructive action hides just that comment; relabel it "Hide
    /// Comment" so the button describes what actually happens rather than
    /// promising an inert "Block Anonymous".
    func blockLabel(for comment: RecipeComment) -> String {
        CommentModerationStore.isAnonymous(author: comment.authorName)
            ? "Hide Comment"
            : "Block \(displayAuthor(for: comment))"
    }

    /// US-44 / CL-139 — return the override view if this row belongs to
    /// the current profile (case-insensitive email match), else `nil` so
    /// ``CommentRow`` falls through to its existing AsyncImage path.
    func ownCommentAvatarOverride(for comment: RecipeComment) -> AnyView? {
        guard let profile = viewModel.profile else { return nil }
        let lhs = comment.authorEmail.lowercased()
        let rhs = profile.email.lowercased()
        guard !lhs.isEmpty, lhs == rhs else { return nil }
        return ownCommentAvatarView(profile: profile)
    }

    /// US-44 / CL-139 — the photo avatar used in own-comment rows. UIKit
    /// gated so the macOS build (which doesn't ship ``ProfilePhotoStoring``)
    /// degrades to the initial-letter avatar (``ProfilePhotoView``'s macOS
    /// branch already does this for us).
    func ownCommentAvatarView(profile: UserProfile) -> AnyView {
        #if canImport(UIKit)
        return AnyView(
            ProfilePhotoView(
                profile: profile,
                diameter: 40,
                photoStore: viewModel.profilePhotoStoreForGate
            )
        )
        #else
        return AnyView(
            ProfilePhotoView(profile: profile, diameter: 40)
        )
        #endif
    }

    /// "Anonymous" fallback for blank-author rows. Shared with the
    /// section file's own helper of the same name (the section itself
    /// keeps this private for its own use; this extension's
    /// `commentRow(for:)` calls into the same logic via the public-in-
    /// module path). Kept on the section type so the
    /// `Self.relativeDateString` call up above resolves cleanly.
    fileprivate func displayAuthor(for comment: RecipeComment) -> String {
        let trimmed = comment.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anonymous" : trimmed
    }
}

/// US-44 / CL-139 / DUT-36 Phase d — the static "Posting as <name>"
/// header that sits above the empty comment editor inside
/// ``RecipeDetailRatingsSection``'s `rateAndReviewCard`. Replaces the
/// retired DUT-28 editable "Display name" + "Email" `TextField`s — the
/// user only chooses stars + types the comment text. The header reads
/// as plain text ("you're posting as this person"), not as another
/// input.
///
/// **Layout.** `HStack` carrying a 32pt ``ProfilePhotoView`` leading +
/// the display name (`DODType.heading` / primary label) + a trailing
/// `Spacer`. Padding-bottom of `DODSpacing.sm` separates the header
/// from the star picker / comment editor below. Avatar diameter chosen
/// at 32pt to sit comfortably inside the composer card (smaller than
/// the 60pt Settings header avatar + the 40pt comment-row avatar).
///
/// **T-744 / CL-141 (DUT-37) — email row removed from the composer
/// surface.** Published comments never expose `author_email` (verified
/// at 3 layers: WP REST `/wp/v2/comments` GET redacts the field
/// server-side per the existing WP privacy posture; ``WPCommentDTO``
/// zeroes the field on parse; ``CommentRow`` has no email render
/// path), so the composer's own-email display was inconsistent with
/// that privacy posture. Email is preserved on Settings → Profile
/// section header + ``ProfileEditView`` (where the user actively
/// manages it) and continues to flow through unchanged as
/// `author_email` in the WP REST submission — only the composer
/// header UI display changes. The inner `VStack` collapses to a
/// single `Text(profile.displayName)`.
///
/// **Accessibility.** `.accessibilityElement(children: .combine)` plus
/// a combined "Posting as <name>" label so VoiceOver announces
/// the header as a single read-only element rather than two
/// independent ones (avatar + name). The email phrase is dropped from
/// the label since it's no longer rendered (announcing it would be
/// misleading to non-sighted users).
///
/// Spec trace: US-44 AC-44.12 (amended T-744 / CL-141); CL-139.
struct PostingAsHeader: View {

    let profile: UserProfile
    #if canImport(UIKit)
    let photoStore: (any ProfilePhotoStoring)?
    #endif

    var body: some View {
        HStack(spacing: DODSpacing.xs) {
            avatar
            Text(profile.displayName)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            Spacer(minLength: 0)
        }
        .padding(.bottom, DODSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posting as \(profile.displayName)")
    }

    @ViewBuilder
    private var avatar: some View {
        #if canImport(UIKit)
        ProfilePhotoView(profile: profile, diameter: 32, photoStore: photoStore)
        #else
        ProfilePhotoView(profile: profile, diameter: 32)
        #endif
    }
}
