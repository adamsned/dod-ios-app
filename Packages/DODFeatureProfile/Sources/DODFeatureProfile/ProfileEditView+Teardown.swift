import DODSupport
import SwiftUI

// DUT-217 — ProfileEditView account teardown. Sign-in (via ``AppleProfileSignIn``)
// writes TWO coupled Keychain rows: the ``UserProfile`` AND the
// ``AppleAuthSession`` (session + Apple refresh token). The editor's "Sign Out"
// and "Delete Profile" buttons must therefore clear BOTH rows — and **Delete
// must revoke** the refresh token (App Store 5.1.1(v)), or this primary
// sign-in surface (since DUT-189) leaves a live, un-revoked token behind.
//
// Extracted from `ProfileEditView.swift` so that file stays under the SwiftLint
// `file_length` cap.
extension ProfileEditView {

    /// Sign Out — clear both coupled rows; do NOT revoke (the user may sign back
    /// in; revocation is reserved for account *deletion*).
    @MainActor
    func handleSignOut() async {
        await teardown(revoke: false, failureMessage: "Couldn't Sign Out. Try Again.")
    }

    /// Delete Profile — clear both coupled rows AND revoke the Apple refresh
    /// token (App Store 5.1.1(v)).
    @MainActor
    func handleDelete() async {
        await teardown(revoke: true, failureMessage: "Couldn't Delete Profile. Try Again.")
    }

    @MainActor
    private func teardown(revoke: Bool, failureMessage: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        // DUT-296 — wire the real GIDSignIn teardown on iOS when Google is
        // configured; macOS / unconfigured builds get a no-op.
        var googleTeardown: (@Sendable (Bool) async -> Void)?
        #if canImport(UIKit)
        if GoogleSignInConfig.isConfigured {
            let provider = GIDSignInProvider()
            googleTeardown = { await provider.teardown(revoke: $0) }
        }
        #endif
        do {
            try await Self.performAccountTeardown(
                revoke: revoke,
                profileStore: store,
                sessionStore: sessionStore,
                guestIdentity: KeychainGuestIdentityStore(),
                revoker: revoker,
                googleTeardown: googleTeardown
            )
            await onProfileChanged()
            dismiss()
        } catch {
            saveError = failureMessage
        }
    }

    /// Pure teardown (no view state) so it's L1-testable. Clears BOTH coupled
    /// rows — the profile AND the session (+ Apple refresh token). When
    /// `revoke` is true (Delete Profile), it also revokes the captured refresh
    /// token (best-effort: the local clear already succeeded, and the token
    /// expires server-side, so a transient revoke failure still deletes
    /// locally). `profileStore.clear()` also deletes the on-disk photo (AC-44.9).
    static func performAccountTeardown(
        revoke: Bool,
        profileStore: any ProfileStoring,
        sessionStore: any AppleAuthSessionStoring,
        guestIdentity: any GuestIdentityStoring,
        revoker: (any SiwaRevoking)?,
        googleTeardown: (@Sendable (Bool) async -> Void)? = nil
    ) async throws {
        let token = (try? sessionStore.load())?.refreshToken
        // Each local clear is independent/best-effort so one failure can't skip
        // the others — especially the revoke + the Google teardown (DUT-268).
        let profileError: Error?
        do {
            try await profileStore.clear()
            profileError = nil
        } catch {
            profileError = error
        }
        try? sessionStore.clear()
        // DUT-298: clear the guest-identity row too. For a signed-in user it
        // mirrors the profile's name+email (the comment/rating author), which
        // would otherwise survive teardown and prefill for the NEXT user.
        try? guestIdentity.clear()
        if revoke, let token, let revoker {
            try? await revoker.revoke(refreshToken: token)
        }
        // DUT-296: clear/revoke the GoogleSignIn SDK's own OAuth tokens — they
        // live in a separate Keychain row the app's clears never touch.
        await googleTeardown?(revoke)
        // Surface a profile-clear failure to the UI, but only after everything
        // else (revoke included) has run.
        if let profileError { throw profileError }
    }
}
