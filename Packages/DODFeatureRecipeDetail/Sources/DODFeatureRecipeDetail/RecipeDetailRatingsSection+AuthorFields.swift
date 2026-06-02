import DODDesignSystem
import SwiftUI

/// DUT-28 — the on-form commenter identity (display name + email) for
/// ``RecipeDetailRatingsSection``. Extracted into this extension so the
/// section's main struct body stays under the SwiftLint `type_body_length`
/// cap (mirrors the view-model `+CommentSubmit` split).
///
/// The name + email replace the retired one-time `GuestIdentitySheet`
/// pop-up: they sit on the form, pre-filled from the saved guest identity,
/// editable inline, validated with the shared `GuestIdentitySheet`
/// validators, and persisted on a valid Submit.
extension RecipeDetailRatingsSection {

    /// The "Display name" + "Email" inputs, placed above the comment box so
    /// the user sets who they are before writing. Each field shows inline
    /// validation feedback once it has content that fails validation, so the
    /// user knows why Submit is disabled. The field copy mirrors the retired
    /// pop-up's data-handling promise (name public, email moderation-only).
    var authorFields: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            authorField(
                .init(
                    title: "Display name",
                    placeholder: "Your name",
                    kind: .name,
                    invalidMessage: "Enter 1 to 40 characters.",
                    accessibilityHint: "Shown next to your comment. 1 to 40 characters."
                ),
                text: Binding(
                    get: { viewModel.commentAuthorName },
                    set: { viewModel.setCommentAuthorName($0) }
                ),
                isValid: viewModel.isAuthorNameValid
            )

            authorField(
                .init(
                    title: "Email",
                    placeholder: "you@example.com",
                    kind: .email,
                    invalidMessage: "Enter a valid email address.",
                    accessibilityHint: "Used only to moderate and reply. Never shown publicly."
                ),
                text: Binding(
                    get: { viewModel.commentAuthorEmail },
                    set: { viewModel.setCommentAuthorEmail($0) }
                ),
                isValid: viewModel.isAuthorEmailValid
            )
        }
    }

    /// Inputs we differentiate on for autofill / keyboard behavior. Local
    /// enum so UIKit's `UITextContentType` never leaks into the macOS build
    /// (this feature module is multi-platform per Package.swift).
    enum AuthorFieldKind {
        case name
        case email
    }

    /// The static descriptors for one on-form identity field. Bundled into a
    /// struct so ``authorField(_:text:isValid:)`` stays under the SwiftLint
    /// parameter-count cap; the live binding + validity flag stay separate
    /// arguments because they change per render.
    struct AuthorFieldSpec {
        let title: String
        let placeholder: String
        let kind: AuthorFieldKind
        let invalidMessage: String
        let accessibilityHint: String
    }

    /// One labelled text field for the on-form identity. Bordered to match
    /// the comment editor; turns the border red and shows `invalidMessage`
    /// once the field is non-empty but fails validation (an empty field is
    /// "not yet filled", not "wrong", so it stays neutral). Carries an
    /// accessibility label + hint per AC.
    func authorField(
        _ spec: AuthorFieldSpec,
        text: Binding<String>,
        isValid: Bool
    ) -> some View {
        // Only flag as an error once the user has typed something invalid;
        // a pristine empty field shouldn't shout red. Uses SwiftUI `.red`
        // for the invalid state to match the `CommentComposer` char-limit
        // counter this form replaces (the design system has no dedicated
        // danger token).
        let showError = !text.wrappedValue.isEmpty && !isValid
        let borderColor: Color =
            showError ? .red : DODColor.labelSecondary.opacity(0.25)

        return VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(spec.title)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)

            authorInput(placeholder: spec.placeholder, text: text, kind: spec.kind)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .padding(DODSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DODSpacing.xs, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .disabled(viewModel.isSubmittingRatingOrComment)
                .accessibilityLabel(spec.title)
                .accessibilityHint(spec.accessibilityHint)

            if showError {
                Text(spec.invalidMessage)
                    .dodFont(DODType.caption)
                    .foregroundStyle(Color.red)
            }
        }
    }

    /// Platform-specialized `TextField`. Keeps the keyboard / autofill hints
    /// for iOS while compiling cleanly on macOS (where those modifiers don't
    /// exist) — same `#if canImport(UIKit)` split as the retired pop-up.
    @ViewBuilder
    func authorInput(
        placeholder: String,
        text: Binding<String>,
        kind: AuthorFieldKind
    ) -> some View {
        let base = TextField(placeholder, text: text)

        #if canImport(UIKit)
        switch kind {
        case .name:
            base
                .textContentType(.name)
                .textInputAutocapitalization(.words)
        case .email:
            base
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled(true)
        }
        #else
        base
        #endif
    }
}
