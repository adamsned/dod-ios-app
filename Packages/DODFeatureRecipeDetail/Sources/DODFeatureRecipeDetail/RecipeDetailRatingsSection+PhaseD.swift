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
/// a `VStack` with the display name (`DODType.bodyEmphasized`) on top +
/// the email (`DODType.caption` / secondary label) below + a trailing
/// `Spacer`. Padding-bottom of `DODSpacing.sm` separates the header
/// from the star picker / comment editor below. Avatar diameter chosen
/// at 32pt to sit comfortably inside the composer card (smaller than
/// the 60pt Settings header avatar + the 40pt comment-row avatar).
///
/// **Accessibility.** `.accessibilityElement(children: .combine)` plus
/// a combined "Posting as <name>, <email>" label so VoiceOver announces
/// the header as a single read-only element rather than three
/// independent ones (avatar + name + email).
///
/// Spec trace: US-44 AC-44.12; CL-139.
struct PostingAsHeader: View {

    let profile: UserProfile
    #if canImport(UIKit)
    let photoStore: (any ProfilePhotoStoring)?
    #endif

    var body: some View {
        HStack(spacing: DODSpacing.xs) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
                Text(profile.email)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, DODSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posting as \(profile.displayName), \(profile.email)")
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
