import DODSupport
import Foundation

// Sign in with Google (DUT-276). The OAuth flow is the GoogleSignIn SDK,
// wrapped behind the `GoogleSignInProviding` seam so this file stays UI/SDK-free
// and L1-testable; the real `GIDSignIn`-backed provider is `GIDSignInProvider`
// (UIKit-gated). The button stays hidden until `GoogleSignInConfig.isConfigured`
// (a real client ID is wired), mirroring how `SiwaRevokeConfig.isConfigured`
// gates the Apple revoke.
//
// Config lives in the app Info.plist (read automatically by the SDK):
//   - `GIDClientID` = the OAuth client ID (also mirrored in `clientID` below so
//     `isConfigured` can gate the button without touching Info.plist at runtime).
//   - `CFBundleURLTypes` = the reversed-client-ID URL scheme (the OAuth redirect).

/// Config gate for Sign in with Google. `isConfigured` is true once a real
/// client ID is wired, which surfaces the Google button in the profile editor.
public enum GoogleSignInConfig {

    /// The Google OAuth client ID (DUT-276). Must match the app Info.plist
    /// `GIDClientID` the GoogleSignIn SDK reads at runtime.
    public static let clientID = "16278307823-o18m60h5rq1m76b9mqam4nhj8po9pipf.apps.googleusercontent.com"

    /// True once a real client ID is wired. The profile editor reads this to
    /// decide whether to surface the Google button.
    public static var isConfigured: Bool { !clientID.isEmpty }
}

/// Result of a Google sign-in attempt. Provider-agnostic identity fields so the
/// success path persists a session the same way Apple does.
public enum GoogleSignInResult: Sendable, Equatable {
    case success(userIdentifier: String, displayName: String?, email: String?)
    /// Google sign-in isn't configured (no client ID). The button is gated on
    /// ``GoogleSignInConfig/isConfigured``, so production never reaches this.
    case notConfigured
    /// The user cancelled, or the flow errored.
    case failed
}

/// Seam for the Google OAuth flow — kept UI/SDK-free so it's L1-testable. The
/// real implementation (`GIDSignInProvider`) calls `GIDSignIn` and maps the user
/// into `.success`. `@MainActor` because presenting the OAuth sheet is a main-
/// thread UI operation.
public protocol GoogleSignInProviding: Sendable {
    @MainActor func signIn() async -> GoogleSignInResult
    /// DUT-296 — clear the GoogleSignIn SDK's own OAuth tokens on Sign Out /
    /// Delete. The SDK keeps its access+refresh tokens in a Keychain row separate
    /// from the app's session, so the app's teardown alone leaves them at rest.
    /// `revoke == true` (Delete Profile) should revoke server-side + clear;
    /// `false` (Sign Out) just clears the local SDK session.
    @MainActor func teardown(revoke: Bool) async
}

/// Fallback provider used when no client ID is wired — always `.notConfigured`.
/// (The button is gated off in that case, so it's only a belt-and-braces default.)
public struct UnconfiguredGoogleSignInProvider: GoogleSignInProviding {
    public init() {}
    @MainActor public func signIn() async -> GoogleSignInResult { .notConfigured }
    @MainActor public func teardown(revoke: Bool) async {}
}

/// Persists a Google sign-in as the app's session + ``UserProfile`` — the
/// Google-side mirror of ``AppleProfileSignIn`` (DUT-276). Google has no
/// Apple-style one-time authorization code / refresh token, so there's no
/// background token exchange or revoke: it just resolves the identity (carrying
/// a returning user's name/email forward via the shared ``AppleCredentialResolver``),
/// saves the session, and writes the profile when both fields are present.
///
/// Reuses ``AppleAuthSession`` as the app's (provider-neutral) session model and
/// ``AppleProfileSignIn/Outcome`` so the host reflects the result identically to
/// the Apple path. Pure value type with injected stores — L1-testable with fakes.
public struct GoogleProfileSignIn: Sendable {

    private let sessionStore: any AppleAuthSessionStoring
    private let profileStore: any ProfileStoring
    /// DUT-279 — used only to revoke a *different* user's orphaned Apple token
    /// when a Google sign-in overwrites it (see `apply`). Same default wiring as
    /// `AppleProfileSignIn`.
    private let revoker: (any SiwaRevoking)?

    public init(
        profileStore: any ProfileStoring,
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil
    ) {
        self.profileStore = profileStore
        self.sessionStore = sessionStore
        self.revoker = revoker
    }

    @discardableResult
    public func apply(
        userIdentifier: String,
        displayName: String?,
        email: String?
    ) async -> AppleProfileSignIn.Outcome {
        let existing = try? sessionStore.load()
        let resolved = AppleCredentialResolver.resolve(
            userIdentifier: userIdentifier,
            credentialDisplayName: displayName,
            credentialEmail: email,
            existing: existing
        )
        // DUT-279: if a DIFFERENT user's Apple session (with a refresh token) is
        // on file, revoke it BEFORE we overwrite it — otherwise that token is
        // orphaned (dropped from the Keychain, never revoked), re-opening the
        // 5.1.1(v) gap. Same-user re-auth carries the token forward instead.
        let orphanedToken =
            existing?.userIdentifier == resolved.userIdentifier ? nil : existing?.refreshToken
        if let orphanedToken, let revoker {
            try? await revoker.revoke(refreshToken: orphanedToken)
        }
        // DUT-375: `resolve` preserves any token already on file for the same
        // user (Google brings none of its own), so we persist `resolved`'s fields
        // rather than re-merging the token here.
        // DUT-701: tag the persisted session as `.google` so the Apple
        // credential-revocation validator skips it (polling Apple for a Google id
        // returns `.notFound` and would force-sign-out the user).
        let googleSession = AppleAuthSession(
            userIdentifier: resolved.userIdentifier,
            displayName: resolved.displayName,
            email: resolved.email,
            refreshToken: resolved.refreshToken,
            provider: .google
        )
        try? sessionStore.save(googleSession)

        var profileSaved = false
        var profileWriteFailed = false
        if let name = resolved.displayName, let mail = resolved.email {
            // DUT-371: don't inherit a DIFFERENT signed-in user's profile id/photo
            // on a shared device (see AppleProfileSignIn). Merge a residual profile
            // only for the same user, or when no prior session exists at all (a
            // guest / manually-created profile this first sign-in is claiming).
            let differentUserSignedIn =
                existing != nil && existing?.userIdentifier != resolved.userIdentifier
            let existingProfile = differentUserSignedIn ? nil : await profileStore.load()
            let profile = UserProfile(
                id: existingProfile?.id ?? UUID(),
                displayName: name,
                email: mail,
                photoFilename: existingProfile?.photoFilename,
                photoOriginalFilename: existingProfile?.photoOriginalFilename
            )
            profileSaved = (try? await profileStore.save(profile)) != nil
            // DUT-891b — mirror the Apple path: both fields were present, so a
            // save that didn't land is a genuine write failure worth surfacing.
            profileWriteFailed = !profileSaved
        }

        return AppleProfileSignIn.Outcome(
            displayName: resolved.displayName,
            email: resolved.email,
            profileSaved: profileSaved,
            signedIn: true,
            profileWriteFailed: profileWriteFailed
        )
    }
}
