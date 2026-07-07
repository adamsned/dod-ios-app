import SwiftUI

/// One-time sheet that collects a display name + email before the user can
/// submit their first comment or rating. Non-dismissible — the host is
/// expected to apply `.interactiveDismissDisabled(true)` to the sheet
/// modifier OR rely on this view's built-in modifier.
///
/// The copy makes the data-handling promise explicit: name is public,
/// email stays with dutchovendaddy.com and is only used for moderation.
/// Keeps us honest with App Store privacy disclosures (constitution §8).
///
/// Spec trace: US-15 (guest identity).
public struct GuestIdentitySheet: View {

    @Binding public var displayName: String
    @Binding public var email: String
    public let isSubmitting: Bool
    public let onContinue: @MainActor () -> Void

    public init(
        displayName: Binding<String>,
        email: Binding<String>,
        isSubmitting: Bool,
        onContinue: @MainActor @escaping () -> Void
    ) {
        self._displayName = displayName
        self._email = email
        self.isSubmitting = isSubmitting
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                Text("Tell Us Who You Are")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    "Your name appears next to your comments. Your email is only used by "
                        + "dutchovendaddy.com to moderate and reply — it's never shared with anyone else."
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DODSpacing.md) {
                field(title: "Display Name", text: $displayName, kind: .name)
                    .accessibilityHint("1 to 40 characters")
                field(title: "Email", text: $email, kind: .email)
            }

            Spacer(minLength: 0)

            continueButton
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DODColor.surface)
        .interactiveDismissDisabled(true)
    }

    /// Inputs we differentiate on. Keeping this enum local avoids leaking
    /// UIKit's `UITextContentType` into the package's macOS build (the
    /// DesignSystem module is multi-platform per Package.swift).
    private enum FieldKind {
        case name
        case email
    }

    private func field(
        title: String,
        text: Binding<String>,
        kind: FieldKind
    ) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(title)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            input(title: title, text: text, kind: kind)
                .padding(DODSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous)
                        .stroke(DODColor.labelSecondary.opacity(0.25), lineWidth: 1)
                )
                .disabled(isSubmitting)
        }
    }

    @ViewBuilder
    private func input(
        title: String,
        text: Binding<String>,
        kind: FieldKind
    ) -> some View {
        let base = TextField(title, text: text)
            .dodFont(DODType.body)

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

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(isSubmitting ? "Saving..." : "Continue")
                .dodFont(DODType.bodyEmphasized)
                // DUT-253: dark label on the muted disabled fill so the default
                // (empty-field) state meets AA contrast; cream only on the accent fill.
                .foregroundStyle(canContinue ? DODColor.cream : DODColor.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                // CL-304 / DUT-537: this is a button, so it takes the pill tier
                // (`Capsule`), not the card-tier `DODRadius.standard`.
                .background(
                    Capsule(style: .continuous)
                        .fill(canContinue ? DODColor.accent : DODColor.labelSecondary.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .accessibilityAddTraits(.isButton)
    }

    /// 1–40 characters after trimming whitespace. Kept in sync with the profile
    /// editor's cap (see `UserProfile.maxDisplayNameLength`).
    static let maxNameLength = 40

    private var canContinue: Bool {
        guard !isSubmitting else { return false }
        return Self.isValidName(displayName) && Self.isValidEmail(email)
    }

    /// 1–``maxNameLength`` characters after trimming whitespace.
    ///
    /// This is the single **structural** name rule shared by BOTH the guest/
    /// comment path and the profile editor (DUT-647). The profile editor's
    /// additional moderation pass (`DisplayNameValidator.validate`) lives in
    /// `DODFeatureProfile`, which depends on this module — so it can't be
    /// referenced here without a dependency cycle. The comment-submit path,
    /// which CAN see both modules, is where the two are composed
    /// (`RecipeDetailViewModel.isAuthorNameValid`).
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...maxNameLength).contains(trimmed.count)
    }

    /// DUT-647 — the SINGLE strong email rule shared by the guest/comment path
    /// and the profile editor. Enforces the profile editor's locked shape
    /// `^[^@\s]+@[^@\s]+\.[^@\s]+$` (rejecting `"a.b@c"`, `"@.com"`,
    /// `"foo@.com"`), replacing the old lax `contains("@") && contains(".")`
    /// that let malformed addresses through.
    ///
    /// Implemented as the same character-class scan as
    /// `UserProfile.matchesEmailPattern` rather than delegating to it: that
    /// type lives in `DODFeatureProfile`, which depends on this module, so a
    /// literal delegate would create a dependency cycle. The two are kept
    /// byte-for-byte identical so both surfaces accept/reject exactly the same
    /// inputs. Final-of-truth validation still happens server-side.
    public static func isValidEmail(_ email: String) -> Bool {
        matchesEmailPattern(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// `^[^@\s]+@[^@\s]+\.[^@\s]+$`. Mirror of
    /// `UserProfile.matchesEmailPattern` (see ``isValidEmail(_:)`` for why it's
    /// duplicated rather than shared). Pure, allocation-free, branch-only.
    private static func matchesEmailPattern(_ input: String) -> Bool {
        guard let atIndex = input.firstIndex(of: "@") else { return false }
        let local = input[..<atIndex]
        let remainder = input[input.index(after: atIndex)...]
        guard !local.isEmpty, !remainder.isEmpty else { return false }
        guard !remainder.contains("@") else { return false }
        let whitespace: CharacterSet = .whitespacesAndNewlines
        if local.unicodeScalars.contains(where: whitespace.contains) { return false }
        if remainder.unicodeScalars.contains(where: whitespace.contains) { return false }
        guard let dotIndex = remainder.firstIndex(of: ".") else { return false }
        let domainHead = remainder[..<dotIndex]
        let domainTail = remainder[remainder.index(after: dotIndex)...]
        return !domainHead.isEmpty && !domainTail.isEmpty
    }
}

#Preview("Empty") {
    StatefulIdentityPreview(name: "", email: "")
}

#Preview("Filled valid") {
    StatefulIdentityPreview(name: "Jamie L.", email: "jamie@example.com")
}

private struct StatefulIdentityPreview: View {
    @State var name: String
    @State var email: String

    init(name: String, email: String) {
        _name = State(initialValue: name)
        _email = State(initialValue: email)
    }

    var body: some View {
        GuestIdentitySheet(
            displayName: $name,
            email: $email,
            isSubmitting: false,
            onContinue: {}
        )
    }
}
