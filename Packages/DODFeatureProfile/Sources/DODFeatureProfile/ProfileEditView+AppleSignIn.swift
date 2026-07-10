import DODDesignSystem
import DODSupport
import SwiftUI

// DUT-189 / DUT-238 — the profile editor's unified sign-in menu: provider
// buttons (Sign in with Apple; Google when configured) + the Display Name /
// Email fields in one `signInSection`. DUT-238 fused the former separate
// `appleSignInSection` + `identitySection` here and removed the duplicate
// Settings ▸ Account section. Split from `ProfileEditView.swift` to keep that
// file under SwiftLint's 400-line `file_length` cap.
extension ProfileEditView {

    /// **Daddy Mode (Phase 1, cosmetic).** Whether the current signed-in session
    /// belongs to the app owner, resolved through the same `sessionStore` the
    /// editor already loads the session from (the app's current-session
    /// accessor). Gated OFF by the `OwnerGate` placeholder — returns `false` for
    /// everyone until Dad's real `sub` is configured, so the owner-only surfaces
    /// (the "Daddy status confirmed" caption + the profile ``OwnerBadge``) stay
    /// hidden. Display-only; authorizes nothing.
    var isCurrentUserOwner: Bool {
        OwnerGate.isOwner((try? sessionStore.load())?.userIdentifier)
    }

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
            // DUT-416 — read-only rows in view mode; the provider buttons +
            // editable fields only render while editing (or setting up a new
            // profile, which is always editing).
            if isEditing {
                editableIdentityFields
            } else {
                identityViewRow(
                    label: "Display Name",
                    value: displayName,
                    identifier: "profile-view-displayname"
                )
                identityViewRow(
                    label: "Email",
                    value: email,
                    identifier: "profile-view-email"
                )
                // Daddy Mode (Phase 1, cosmetic) — owner-only confirmation caption
                // below the email in view mode. Display-only: does nothing, gated
                // OFF for everyone until `OwnerGate.ownerUserIdentifier` is set.
                if isCurrentUserOwner {
                    Text("Authentication successful. Daddy status confirmed.")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .accessibilityIdentifier("profile-view-daddy-status")
                }
            }
        } footer: {
            if isEditing { signInSectionFooter }
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// DUT-416 — the editable identity surface (provider sign-in buttons for a
    /// new profile + the Display Name / Email TextFields with their live DUT-414
    /// / DUT-415 inline errors). Shown only in edit mode.
    @ViewBuilder
    private var editableIdentityFields: some View {
        #if canImport(UIKit)
        if existingProfile == nil {
            AppleProfileSignInButton(profileStore: store) { outcome in
                handleAppleSignIn(outcome)
            } onError: { message in
                // DUT-636: surface a real SiwA failure (cancellation stays silent,
                // filtered out in the button) via the editor's existing error row.
                saveError = message
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

        // DUT-414 / DUT-415 — each required field carries a live error
        // message directly below it (required when blank; "pick a different
        // name" when the display name fails moderation). The same checks gate
        // the Save button (`isFormValid`).
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            TextField("Display name", text: $displayName)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.name)
                .accessibilityIdentifier("profile-edit-displayname")
                // DUT-693 PR4 — mirror the email field (DUT-410): bind the inline
                // validation error to the field so VoiceOver reads it on focus
                // instead of leaving it orphaned below the TextField.
                .accessibilityValue(displayNameFieldError ?? "")
                #if os(iOS)
            .autocapitalization(.words)
                #endif
            if let displayNameFieldError {
                Text(displayNameFieldError)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityIdentifier("profile-edit-displayname-error")
            }
        }

        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            TextField("Email", text: $email)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("profile-edit-email")
                // DUT-410 — bind the validation error to the field itself so
                // VoiceOver reads "Invalid email" on the Email TextField rather
                // than leaving the error orphaned in the section footer.
                .accessibilityValue(emailValidationError == nil ? "" : "Invalid email")
                #if os(iOS)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled(true)
                #endif
            if let emailFieldError {
                Text(emailFieldError)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityIdentifier("profile-edit-email-error")
            }
        }
    }

    /// DUT-416 — a single read-only identity row for view mode: a small
    /// secondary-colored label stacked above the value (mirrors the edit-mode
    /// field layout so the page doesn't jump when toggling modes).
    @ViewBuilder
    private func identityViewRow(label: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Text(value)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
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
        // DUT-506 — a blank-id credential persisted no session (a non-event); stay
        // silent, exactly like the button's own guard.
        guard outcome.signedIn else { return }
        hasSession = true  // DUT-281 — a session was persisted; keep Sign Out reachable
        if let name = outcome.displayName { displayName = name }
        if let mail = outcome.email { email = mail }
        // DUT-891b — surface an error ONLY on a genuine write failure (the
        // credential carried a name + email but the Keychain/profile save failed —
        // the "Couldn't Save Your Profile" case). Do NOT treat a plain
        // `profileSaved == false` as an error: on a re-auth (Apple releases the
        // name/email only on the FIRST authorization) or a second device, the
        // fields come back nil with nothing on file to carry forward, so there is
        // simply nothing to write. The user IS signed in — that's a success, not
        // the "Couldn't Save Your Profile" failure DUT-695 previously reported here.
        guard !outcome.profileWriteFailed else {
            saveError = "Couldn't Save Your Profile. Try Again."
            return
        }
        // DUT — confirm the successful sign-in with a `.success` tap (mirrors the
        // Save path). Bump before any `dismiss()` — the Save path proves the
        // trigger fires even when the view is dismissing (`+Save.swift`).
        authSuccessTick &+= 1
        // Apple withheld the name/email and nothing was on file: the user is
        // signed in, but there's nothing to auto-fill, so keep the editor open for
        // manual completion (no error, no dismiss). Only auto-dismiss when a full
        // profile was written in one tap.
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
            // DUT-891b — mirror the Apple handler: surface the error row ONLY on a
            // genuine write failure (fields present, save failed), never on a plain
            // `profileSaved == false` (nothing to write is not a failure).
            guard !outcome.profileWriteFailed else {
                saveError = "Couldn't Save Your Profile. Try Again."
                return
            }
            // DUT — mirror the Apple handler: a `.success` tap confirms the
            // successful Google sign-in.
            authSuccessTick &+= 1
            // Nothing to auto-fill → keep the editor open for manual entry.
            guard outcome.profileSaved else { return }
            await onProfileChanged()
            dismiss()
        }
    }
    #endif
}
