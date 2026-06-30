#if canImport(UIKit)
import DODDesignSystem
import SwiftUI

/// "Sign in with Google" button — SCAFFOLD (see `GoogleProfileSignIn`). Mirrors
/// `AppleProfileSignInButton`'s 44pt full-width shape. The caller gates it behind
/// ``GoogleSignInConfig/isConfigured``, so it only appears once a real client ID
/// is wired. The provider seam is injected — `UnconfiguredGoogleSignInProvider`
/// by default, the real `GIDSignIn`-backed one once the SDK lands.
///
/// TODO(2026-06-23, nadams): swap the placeholder `g.circle.fill` symbol for the official
/// Google logo asset + the standard Google button styling (white background,
/// Google "G"), per Google's sign-in branding guidelines.
public struct GoogleProfileSignInButton: View {

    private let provider: any GoogleSignInProviding
    private let onComplete: @MainActor (GoogleSignInResult) -> Void

    public init(
        provider: any GoogleSignInProviding = GIDSignInProvider(),
        onComplete: @MainActor @escaping (GoogleSignInResult) -> Void
    ) {
        self.provider = provider
        self.onComplete = onComplete
    }

    public var body: some View {
        Button {
            Task { @MainActor in
                onComplete(await provider.signIn())
            }
        } label: {
            Label("Sign in with Google", systemImage: "g.circle.fill")
                .dodFont(DODType.body)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .dodBorderedButton()
        .tint(DODColor.label)
        .accessibilityIdentifier("profile-sign-in-google")
    }
}
#endif
