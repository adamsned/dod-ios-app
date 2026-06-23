#if canImport(UIKit)
import GoogleSignIn
import UIKit

/// Real Google sign-in provider backed by the GoogleSignIn SDK (DUT-276). Reads
/// the client ID from the app Info.plist `GIDClientID` (the SDK does this
/// automatically), presents the OAuth flow from the frontmost view controller,
/// and maps the signed-in `GIDGoogleUser` into the provider-agnostic
/// ``GoogleSignInResult``. Injected into ``GoogleProfileSignInButton``; tests use
/// a fake (or ``UnconfiguredGoogleSignInProvider``) instead.
public struct GIDSignInProvider: GoogleSignInProviding {

    public init() {}

    @MainActor
    public func signIn() async -> GoogleSignInResult {
        guard let presenter = Self.topViewController() else { return .failed }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            let user = result.user
            return .success(
                // userID is the stable Google account identifier; fall back to
                // the email so the session always has a non-empty key.
                userIdentifier: user.userID ?? user.profile?.email ?? "",
                displayName: user.profile?.name,
                email: user.profile?.email
            )
        } catch {
            // GIDSignIn surfaces user-cancellation as an error too; treat both
            // the cancel and any failure as a no-op `.failed` (the host ignores it).
            return .failed
        }
    }

    /// The frontmost presented view controller in the active foreground scene —
    /// what the Google OAuth sheet presents from.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let keyWindow = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
