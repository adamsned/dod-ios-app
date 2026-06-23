import DODDesignSystem
import SwiftUI

// DUT-189 — Sign in with Apple on the profile editor (the sign-in entry moved
// here off Settings ▸ Account). Also holds `identitySection`, moved out of
// `ProfileEditView.swift` so that file stays under SwiftLint's 400-line
// `file_length` cap once this section was added.
extension ProfileEditView {

    /// Identity fields — Display Name + Email (both required, basic email regex
    /// via ``UserProfile/validateEmail(_:)``). Body-referenced by the main
    /// file's `Form`.
    @ViewBuilder
    var identitySection: some View {
        Section {
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
            if let emailValidationError {
                Text(emailValidationError)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// Sign in with Apple for a NEW profile: one tap signs the user in and fills
    /// the name/email fields below. Only shown when setting up a profile for the
    /// first time (`existingProfile == nil`) — editing an existing profile hides
    /// it, mirroring `signOutSection`'s `existingProfile != nil` gate. Reachable
    /// from Settings ▸ Profile, the iPad sidebar Profile, and the recipe ratings
    /// gate (all present this editor).
    @ViewBuilder
    var appleSignInSection: some View {
        #if canImport(UIKit)
        if existingProfile == nil {
            Section {
                AppleProfileSignInButton(profileStore: store) { outcome in
                    handleAppleSignIn(outcome)
                }
                // Sign in with Google — scaffold, gated behind a real client ID
                // (GoogleSignInConfig.isConfigured) so it stays hidden until wired.
                if GoogleSignInConfig.isConfigured {
                    GoogleProfileSignInButton { result in
                        handleGoogleSignIn(result)
                    }
                }
            } footer: {
                Text("Sign in to fill your name and email automatically, or just enter them below.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
        #endif
    }

    #if canImport(UIKit)
    /// Reflect a completed Sign in with Apple: fill the fields from the
    /// credential, and — when a valid profile was written in one tap — refresh
    /// the parent + dismiss. When Apple withheld the name/email (and none was on
    /// file) the fields stay as-is and the editor remains open for manual
    /// completion; the session is persisted regardless (the user is signed in).
    @MainActor
    func handleAppleSignIn(_ outcome: AppleProfileSignIn.Outcome) {
        if let name = outcome.displayName { displayName = name }
        if let mail = outcome.email { email = mail }
        guard outcome.profileSaved else { return }
        Task {
            await onProfileChanged()
            dismiss()
        }
    }

    /// Reflect a completed Sign in with Google (SCAFFOLD — see
    /// `GoogleProfileSignIn`). Gated behind `GoogleSignInConfig.isConfigured`, so
    /// `.notConfigured` never reaches a production user. On `.success` it fills
    /// the name/email fields like Apple does. TODO(2026-06-23, nadams): persist the identity
    /// as a session + profile by generalizing `AppleProfileSignIn`'s persist path
    /// to be provider-agnostic (Google has no Apple-style refresh-token exchange).
    @MainActor
    func handleGoogleSignIn(_ result: GoogleSignInResult) {
        guard case .success(_, let displayName, let email) = result else { return }
        if let displayName { self.displayName = displayName }
        if let email { self.email = email }
    }
    #endif
}
