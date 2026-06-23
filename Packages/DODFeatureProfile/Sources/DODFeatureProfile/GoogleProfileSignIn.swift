import Foundation

// Sign in with Google — SCAFFOLD (Linear ticket pending; "add Google alongside
// Sign in with Apple"). The button + provider seam ship now but stay HIDDEN
// behind `GoogleSignInConfig.isConfigured` until a real Google OAuth client ID
// is provisioned — exactly how `SiwaRevokeConfig.isConfigured` gates the Apple
// revoke. Nothing here imports the GoogleSignIn SDK, so the app compiles +
// CI passes without it; the real provider is added at wire-up time.
//
// TO TURN GOOGLE SIGN-IN ON (the "wire the ID later" step):
//   1. Add the **GoogleSignIn** Swift package to the project (project.yml +
//      DODFeatureProfile's Package dependencies).
//   2. Create an OAuth 2.0 client ID (iOS) in Google Cloud Console; add the
//      client ID and its **reversed-client-ID URL scheme** to the app Info.plist.
//   3. Set `GoogleSignInConfig.clientID` (or read it from Info.plist) so
//      `isConfigured` flips true and the button appears.
//   4. Replace `UnconfiguredGoogleSignInProvider` with a real provider that
//      calls `GIDSignIn.sharedInstance.signIn(...)` and maps the `GIDGoogleUser`
//      (`userID`, `profile?.name`, `profile?.email`) into `.success`.
//   5. Persist the `.success` identity as a session + profile by generalizing
//      `AppleProfileSignIn`'s persist path to be provider-agnostic (the session
//      model is Apple-named today but functionally provider-neutral).
//   6. Use the official Google logo/branding on the button (see
//      `GoogleProfileSignInButton`), per Google's sign-in branding guidelines.

/// Config gate for Sign in with Google. `isConfigured` is false until a real
/// client ID is wired, so the Google button never ships visible-but-broken.
public enum GoogleSignInConfig {

    /// The Google OAuth client ID. Empty placeholder until provisioned — keep it
    /// empty so `isConfigured` stays false and the button stays hidden.
    public static let clientID = ""

    /// True once a real client ID is wired. The profile editor reads this to
    /// decide whether to surface the Google button.
    public static var isConfigured: Bool { !clientID.isEmpty }
}

/// Result of a Google sign-in attempt. Provider-agnostic identity fields so the
/// success path can persist a session the same way Apple does.
public enum GoogleSignInResult: Sendable, Equatable {
    case success(userIdentifier: String, displayName: String?, email: String?)
    /// Google sign-in isn't configured (no client ID / SDK). The button is gated
    /// on ``GoogleSignInConfig/isConfigured``, so production never reaches this.
    case notConfigured
    case failed
}

/// Seam for the Google OAuth flow — kept UI/SDK-free so it's L1-testable and so
/// the app compiles without the GoogleSignIn SDK. The real implementation (added
/// at wire-up) calls `GIDSignIn` and maps the user into `.success`.
public protocol GoogleSignInProviding: Sendable {
    func signIn() async -> GoogleSignInResult
}

/// Default provider until the SDK + client ID land — always `.notConfigured`.
public struct UnconfiguredGoogleSignInProvider: GoogleSignInProviding {
    public init() {}
    public func signIn() async -> GoogleSignInResult { .notConfigured }
}
