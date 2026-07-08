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
                googleTeardown: googleTeardown,
                extraTeardown: extraTeardown
            )
            // DUT — confirm the completed Sign Out / Delete with a `.success` tap
            // (both funnel through here) so the teardown doesn't finish silently.
            // Bump before `dismiss()` — the Save path proves the trigger still
            // fires as the view dismisses.
            authSuccessTick &+= 1
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
    /// locally). DUT-678: a revoke failure no longer stays silent — it's
    /// logged as an error (see below) so a stranded, un-revoked Apple token
    /// (5.1.1(v)) is observable rather than swallowed, without blocking the
    /// user's deletion. `profileStore.clear()` also deletes the on-disk photo
    /// (AC-44.9).
    static func performAccountTeardown(
        revoke: Bool,
        profileStore: any ProfileStoring,
        sessionStore: any AppleAuthSessionStoring,
        guestIdentity: any GuestIdentityStoring,
        revoker: (any SiwaRevoking)?,
        googleTeardown: (@Sendable (Bool) async -> Void)? = nil,
        extraTeardown: (@MainActor (Bool) async -> Void)? = nil
    ) async throws {
        // DUT-367: distinguish "no session" from "the Keychain READ failed." A bare
        // `try?` collapsed both to nil, so a transient Keychain error during Delete
        // (e.g. `errSecInteractionNotAllowed` just after the device locks) silently
        // skipped revocation while still clearing the session — stranding a live,
        // un-revoked Apple token (App Store 5.1.1(v)). On a revoke teardown,
        // propagate a read failure and abort BEFORE clearing anything, so the user
        // retries Delete rather than orphaning the token at Apple. (`load()` returns
        // nil — it does NOT throw — for a genuinely absent session, so a real Delete
        // with no token still proceeds to clear.) Sign Out doesn't revoke, so a read
        // failure there stays best-effort.
        let token: String?
        if revoke {
            token = try sessionStore.load()?.refreshToken
        } else {
            token = (try? sessionStore.load())?.refreshToken
        }
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
            // DUT-678: the revoke is best-effort for the USER — the local rows
            // are already cleared and the token expires server-side, so a
            // transient failure must NOT block or fail account deletion. But a
            // silently-swallowed `try?` made a failed revoke invisible, so we
            // couldn't tell whether 5.1.1(v) actually held. Keep deletion
            // non-blocking, but SURFACE the failure as an error log (the token
            // itself is never logged) so a stranded, un-revoked Apple token is
            // observable in the field rather than lost.
            do {
                try await revoker.revoke(refreshToken: token)
            } catch {
                DODLog.network.error(
                    "SiwA revoke FAILED during account deletion (App Store 5.1.1(v)); local teardown still completed. error=\(String(describing: error), privacy: .public)"
                )
            }
        }
        // DUT-296: clear/revoke the GoogleSignIn SDK's own OAuth tokens — they
        // live in a separate Keychain row the app's clears never touch.
        await googleTeardown?(revoke)
        // DUT-565: clear cross-package local state the profile teardown can't
        // reach directly — recent searches (raw query strings) + comment
        // moderation (blocked authors / hidden comment IDs). Injected by the App
        // composition root (which owns those stores) so DODFeatureProfile keeps
        // no dependency edge onto Search / RecipeDetail. Best-effort like the
        // other seams, and applied on BOTH Sign Out and Delete — matching the
        // guest-identity "don't prefill for the NEXT user" treatment above.
        await extraTeardown?(revoke)
        // Surface a profile-clear failure to the UI, but only after everything
        // else (revoke included) has run.
        if let profileError { throw profileError }
    }
}
