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
                Text("Tell us who you are")
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
                field(title: "Display name", text: $displayName, kind: .name)
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

    private var canContinue: Bool {
        guard !isSubmitting else { return false }
        return Self.isValidName(displayName) && Self.isValidEmail(email)
    }

    /// 1–40 characters after trimming whitespace.
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...40).contains(trimmed.count)
    }

    /// Basic structural check: trimmed, contains `@` and `.`, no spaces.
    /// Intentionally lax — final-of-truth validation happens server-side.
    public static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" ") else { return false }
        return trimmed.contains("@") && trimmed.contains(".")
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
