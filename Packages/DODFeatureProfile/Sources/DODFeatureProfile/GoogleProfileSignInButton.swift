#if canImport(UIKit)
import DODDesignSystem
import SwiftUI

/// "Sign in with Google" button. Mirrors `AppleProfileSignInButton`'s 44pt
/// full-width shape. The caller gates it behind ``GoogleSignInConfig/isConfigured``,
/// so it only appears once a real client ID is wired. The provider seam is
/// injected and now defaults to the live, `GIDSignIn`-backed ``GIDSignInProvider``
/// (the SDK has landed); tests inject a fake through the same `provider` parameter.
///
/// TODO(2026-07-07, nadams): swap the placeholder `g.circle.fill` symbol for the official
/// Google logo asset + the standard Google button styling (white background,
/// Google "G"), per Google's sign-in branding guidelines.
public struct GoogleProfileSignInButton: View {

    private let provider: any GoogleSignInProviding
    private let onComplete: @MainActor (GoogleSignInResult) -> Void
    @State private var isSigningIn = false

    public init(
        provider: any GoogleSignInProviding = GIDSignInProvider(),
        onComplete: @MainActor @escaping (GoogleSignInResult) -> Void
    ) {
        self.provider = provider
        self.onComplete = onComplete
    }

    public var body: some View {
        Button {
            guard !isSigningIn else { return }
            isSigningIn = true
            Task { @MainActor in
                defer { isSigningIn = false }
                onComplete(await provider.signIn())
            }
        } label: {
            Label("Sign in with Google", systemImage: "g.circle.fill")
                .dodFont(DODType.body)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .disabled(isSigningIn)
        .dodBorderedButton()
        .tint(DODColor.label)
        .accessibilityIdentifier("profile-sign-in-google")
    }
}
#endif
