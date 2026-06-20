import DODSupport
import Foundation
import Observation

/// State + actions for the Settings → Account section (US-46 / DUT-16 Phase a,
/// AC-46.2..46.4). Owns the on-device ``AppleAuthSession`` via an injected
/// ``AppleAuthSessionStoring`` and turns a Sign in with Apple credential into a
/// persisted session through the pure ``AppleCredentialResolver`` (so the
/// first-auth name/email merge is unit-tested without `AuthenticationServices`).
///
/// Guest mode (US-15) stays the default: a `nil` ``session`` means signed-out,
/// and every other surface keeps working unchanged. Signing in only adds a
/// durable identity for comments/ratings (and, in a later phase, cross-device
/// state). The store is injected so the L1 suite drives an
/// ``InMemoryAppleAuthSessionStore``.
@Observable
@MainActor
public final class AccountViewModel {

    /// The current signed-in session, or `nil` when signed out (guest mode).
    public private(set) var session: AppleAuthSession?

    private let store: any AppleAuthSessionStoring

    public init(store: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore()) {
        self.store = store
        // Seed from the store so a returning user lands signed-in. `try?` —
        // a Keychain read failure degrades to signed-out (guest), never a crash.
        self.session = try? store.load()
    }

    public var isSignedIn: Bool { session != nil }

    /// Apply a fresh Sign in with Apple credential: resolve it against any
    /// existing session (carrying the first-auth name/email forward for the
    /// SAME Apple user via ``AppleCredentialResolver``), persist, and publish.
    /// The view extracts `(user, fullName, email)` from the
    /// `ASAuthorizationAppleIDCredential` and passes them here, so this method
    /// is `AuthenticationServices`-free and fully testable.
    public func applySignIn(userIdentifier: String, displayName: String?, email: String?) {
        let resolved = AppleCredentialResolver.resolve(
            userIdentifier: userIdentifier,
            credentialDisplayName: displayName,
            credentialEmail: email,
            existing: try? store.load()
        )
        try? store.save(resolved)
        session = (try? store.load()) ?? resolved
    }

    /// AC-46.3 — Sign Out: clear the local session and fall back to guest mode.
    public func signOut() {
        try? store.clear()
        session = nil
    }

    /// AC-46.3 — in-app Delete Account (App Store Guideline 5.1.1(v)). In Phase a
    /// this clears the local session; a later phase also revokes the Apple token
    /// (`ASAuthorizationAppleIDProvider`) and deletes the server-side record.
    public func deleteAccount() {
        try? store.clear()
        session = nil
    }
}
