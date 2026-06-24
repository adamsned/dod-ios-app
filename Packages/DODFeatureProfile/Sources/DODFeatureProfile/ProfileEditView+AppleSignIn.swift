import DODDesignSystem
import SwiftUI

// DUT-189 / DUT-238 — the profile editor's unified sign-in menu: provider
// buttons (Sign in with Apple; Google when configured) + the Display Name /
// Email fields in one `signInSection`. DUT-238 fused the former separate
// `appleSignInSection` + `identitySection` here and removed the duplicate
// Settings ▸ Account section. Split from `ProfileEditView.swift` to keep that
// file under SwiftLint's 400-line `file_length` cap.
extension ProfileEditView {

    /// DUT-238 — the unified sign-in menu: the provider buttons (Sign in with
    /// Apple; Sign in with Google when configured) sit in the SAME section as the
    /// manual Display Name / Email fields, so email + SiwA + Google read as one
    /// "sign in" choice. Replaces the separate `appleSignInSection` +
    /// `identitySection` and the now-removed duplicate Settings ▸ Account
    /// section. Provider buttons show only while setting up a NEW profile
    /// (`existingProfile == nil`); editing an existing profile shows just the
    /// fields (both required, basic email regex via
    /// ``UserProfile/validateEmail(_:)``). Body-referenced by the main `Form`.
    @ViewBuilder
    var signInSection: some View {
        Section {
            #if canImport(UIKit)
            if existingProfile == nil {
                AppleProfileSignInButton(profileStore: store) { outcome in
                    handleAppleSignIn(outcome)
                }
                // Sign in with Google (DUT-276) — shown once a real client ID is
                // wired (GoogleSignInConfig.isConfigured); the GIDSignIn flow runs
                // via GoogleProfileSignInButton's default GIDSignInProvider.
                if GoogleSignInConfig.isConfigured {
                    GoogleProfileSignInButton { result in
                        handleGoogleSignIn(result)
                    }
                }
            }
            #endif

            TextField("Display name", text: $displayName)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.name)
                .accessibilityIdentifier("profile-edit-displayname")
                #if os(iOS)
            .autocapitalization(.words)
                #endif

            TextField("Email", text: $email)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("profile-edit-email")
                #if os(iOS)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled(true)
                #endif
        } footer: {
            signInSectionFooter
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// Footer for ``signInSection``: the email-validation error when present,
    /// else (only while setting up a new profile) the hint that a provider
    /// sign-in auto-fills the fields.
    @ViewBuilder
    private var signInSectionFooter: some View {
        if let emailValidationError {
            Text(emailValidationError)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        } else if existingProfile == nil {
            Text("Sign in to fill your name and email automatically, or just enter your details below.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
    }

    #if canImport(UIKit)
    /// Reflect a completed Sign in with Apple: fill the fields from the
    /// credential, and — when a valid profile was written in one tap — refresh
    /// the parent + dismiss. When Apple withheld the name/email (and none was on
    /// file) the fields stay as-is and the editor remains open for manual
    /// completion; the session is persisted regardless (the user is signed in).
    @MainActor
    func handleAppleSignIn(_ outcome: AppleProfileSignIn.Outcome) {
        hasSession = true  // DUT-281 — a session was persisted; keep Sign Out reachable
        if let name = outcome.displayName { displayName = name }
        if let mail = outcome.email { email = mail }
        guard outcome.profileSaved else { return }
        Task {
            await onProfileChanged()
            dismiss()
        }
    }

    /// Reflect a completed Sign in with Google (DUT-276) — the Google mirror of
    /// `handleAppleSignIn`. `.success` persists the session + profile via
    /// `GoogleProfileSignIn`, fills the name/email fields, and (when a valid
    /// profile was written in one tap) refreshes the parent + dismisses. A
    /// cancel/failure (`.failed`) or the gated-off `.notConfigured` is a no-op.
    @MainActor
    func handleGoogleSignIn(_ result: GoogleSignInResult) {
        guard case .success(let userIdentifier, let displayName, let email) = result else { return }
        hasSession = true  // DUT-281 — a session will be persisted; keep Sign Out reachable
        Task {
            let outcome = await GoogleProfileSignIn(profileStore: store).apply(
                userIdentifier: userIdentifier,
                displayName: displayName,
                email: email
            )
            if let name = outcome.displayName { self.displayName = name }
            if let mail = outcome.email { self.email = mail }
            guard outcome.profileSaved else { return }
            await onProfileChanged()
            dismiss()
        }
    }
    #endif
}
