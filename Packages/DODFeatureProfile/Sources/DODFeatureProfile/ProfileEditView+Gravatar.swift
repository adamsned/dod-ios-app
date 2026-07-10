import DODDesignSystem
import SwiftUI

// DUT — Gravatar nudge for the profile photo header.
//
// The locally-cropped Keychain profile photo (``ProfilePhotoStore`` /
// ``UserProfile/photoFilename``) shows ONLY on the user's own comments inside
// this app; it never propagates to the website or to other users. Comment
// avatars everywhere (app + website) come from Gravatar, keyed on the comment's
// email (`WPDTO.Comment.bestAvatarURL` → `RecipeComment.avatarURL`, rendered in
// `CommentRow`). So the only way to get one photo everywhere the user comments
// with the same email is for them to set a Gravatar for that email. This
// understated caption + accent `Link` tells them that.
//
// Extracted into its own extension file (like `+Photo` / `+Voice` /
// `+CloudSync`) so `ProfileEditView+Photo.swift` stays under the SwiftLint
// 400-line `file_length` cap. Purely informational — touches no comment/avatar
// logic. Not owner-gated: shown for every user while they edit their photo.

extension ProfileEditView {

    /// The web destination the Gravatar nudge opens. Stored as a `String` (not
    /// a force-unwrapped `URL`) so it stays SwiftLint-clean (`force_unwrapping`
    /// is an error in this repo) and the L1 suite can pin the literal; the
    /// `Link` builds its `URL` with `if let`. Matches the
    /// `SettingsViewModel.privacyPolicyURLString` convention.
    static let gravatarURLString = "https://gravatar.com"

    /// Subtle caption + tappable link surfaced under the photo header while
    /// editing. Accent (burnt-orange) is applied to the tappable link only,
    /// per the accent conventions (never a full content-card fill).
    @ViewBuilder
    var gravatarNudge: some View {
        VStack(spacing: DODSpacing.xxs) {
            Text(gravatarNudgeCaption)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let url = URL(string: Self.gravatarURLString) {
                Link(destination: url) {
                    Text("Set Up Gravatar")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.accent)
                }
                .accessibilityIdentifier("profile-edit-gravatar-link")
                .accessibilityLabel("Set up Gravatar, opens in browser")
            }
        }
    }

    /// Sentence-case caption body for the Gravatar nudge (this is caption copy,
    /// NOT a Title-Case header). Email-specific when the profile has an email;
    /// a generic "your email" otherwise. No em dashes (app-copy rule).
    var gravatarNudgeCaption: String {
        email.isEmpty
            ? "Your photo shows only in the Dutch Oven Daddy app. To show it on the website and everywhere you comment, set a photo at Gravatar for your email."
            : "Your photo shows only in the Dutch Oven Daddy app. To show it on the website and everywhere you comment, set a photo at Gravatar for this email."
    }
}
