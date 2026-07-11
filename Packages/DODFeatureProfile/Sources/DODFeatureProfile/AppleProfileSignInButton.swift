#if canImport(UIKit)
import AuthenticationServices
import DODSupport
import SwiftUI
import UIKit

/// The native **Sign in with Apple** button for the profile-login surfaces —
/// the shared control that replaced the Settings ▸ Account sign-in button when
/// the entry moved onto the profile editor (DUT-189). On success it runs
/// ``AppleProfileSignIn`` (persist session + write profile + background
/// refresh-token exchange) and hands the host an ``AppleProfileSignIn/Outcome``
/// so it can fill its fields and dismiss.
///
/// DUT-891 — the flow is driven through an explicit ``ASAuthorizationController``
/// with our own presentation anchor, rather than SwiftUI's `SignInWithAppleButton`
/// (whose implicit anchor fails to resolve from inside the iPad sidebar's
/// **form-sheet** profile editor — the auth sheet never presents and sign-in
/// silently does nothing on iPad). The button is the native
/// `ASAuthorizationAppleIDButton` (identical `.black` / 44pt look), and the
/// credential processing is byte-for-byte the prior handler (DUT-506 blank-id
/// guard + DUT-636 error classification + the L1-tested `AppleProfileSignIn`).
public struct AppleProfileSignInButton: View {

    private let profileStore: any ProfileStoring
    private let onComplete: @MainActor (AppleProfileSignIn.Outcome) -> Void
    private let onError: (@MainActor (String) -> Void)?

    /// DUT-891 — retained for the button's lifetime so the controller's delegate
    /// + presentation-context provider survive the async auth callback. A
    /// released delegate silently drops the result (a "nothing happens" failure).
    @State private var coordinator = AppleSignInCoordinator()

    public init(
        profileStore: any ProfileStoring,
        onComplete: @MainActor @escaping (AppleProfileSignIn.Outcome) -> Void,
        onError: (@MainActor (String) -> Void)? = nil
    ) {
        self.profileStore = profileStore
        self.onComplete = onComplete
        self.onError = onError
    }

    public var body: some View {
        AppleIDButtonRepresentable {
            coordinator.start(
                profileStore: profileStore,
                onComplete: onComplete,
                onError: onError
            )
        }
        .frame(height: 44)
        .accessibilityIdentifier("profile-sign-in-apple")
    }

    /// DUT-636 — classify a Sign in with Apple failure. Returns `nil` when the
    /// user simply canceled / dismissed the sheet (no error UI — that's a
    /// deliberate back-out), and a short user-facing message for a real failure
    /// the host should surface. `unknown` is bucketed with cancellation: the
    /// system reports a user-driven dismissal as `.unknown` on some OS versions.
    static func userFacingErrorMessage(for error: any Error) -> String? {
        guard let authError = error as? ASAuthorizationError else {
            return "Couldn't Sign In With Apple. Try Again."
        }
        switch authError.code {
        case .canceled, .unknown:
            return nil
        case .failed, .invalidResponse, .notHandled, .notInteractive:
            return "Couldn't Sign In With Apple. Try Again."
        @unknown default:
            return "Couldn't Sign In With Apple. Try Again."
        }
    }
}

/// DUT-891 — the system Apple button rendered via UIKit so the look is identical
/// while the tap routes through our own ``ASAuthorizationController`` (SwiftUI's
/// `SignInWithAppleButton` gives no way to inject a presentation anchor).
private struct AppleIDButtonRepresentable: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}

/// DUT-891 — runs the Sign in with Apple request through an explicit
/// `ASAuthorizationController` with a presentation anchor, so the auth sheet
/// presents on iPad (from inside the sidebar's form-sheet editor) as well as
/// iPhone. Credential processing matches the former inline handler exactly.
@MainActor
final class AppleSignInCoordinator: NSObject {
    private var profileStore: (any ProfileStoring)?
    private var onComplete: (@MainActor (AppleProfileSignIn.Outcome) -> Void)?
    private var onError: (@MainActor (String) -> Void)?
    /// Retain the in-flight controller so the delegate callbacks fire — a
    /// released controller silently drops the whole flow.
    private var activeController: ASAuthorizationController?
    /// DUT-928 — a strong self-reference held ONLY for the duration of an
    /// in-flight request, so the coordinator (and thus its delegate +
    /// presentation-context provider) survives even if SwiftUI tears down the
    /// owning view's `@State` while the auth sheet is up. On iPad the profile
    /// editor is a form sheet: completing Sign in with Apple re-renders that
    /// sheet, which can release the `@State`-held coordinator before the async
    /// callback lands — and `ASAuthorizationController.delegate` is `weak`, so
    /// the credential is silently dropped and the app never sees the sign-in
    /// ("signs in but never actually signed in"). Cleared when the flow ends.
    private var retainedSelf: AppleSignInCoordinator?

    func start(
        profileStore: any ProfileStoring,
        onComplete: @escaping @MainActor (AppleProfileSignIn.Outcome) -> Void,
        onError: (@MainActor (String) -> Void)?
    ) {
        self.profileStore = profileStore
        self.onComplete = onComplete
        self.onError = onError
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        activeController = controller
        retainedSelf = self
        controller.performRequests()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    /// DUT-891 — the foreground-active scene's key window, so the auth sheet has
    /// a valid anchor even when the presenting editor is an iPad form sheet.
    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene =
            scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        let window =
            windowScene?.windows.first(where: \.isKeyWindow)
            ?? windowScene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        activeController = nil
        // DUT-928 — release the in-flight self-retention at scope exit. The
        // credential fields + `onComplete` are captured strongly by the `Task`
        // below, so the sign-in still completes even if the coordinator itself
        // is deallocated the instant this method returns.
        defer { retainedSelf = nil }
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            // DUT-928 diagnostic (TEMPORARY): surface a normally-silent drop.
            onError?("Sign-in diagnostic: no Apple ID credential returned.")
            return
        }
        // Capture the credential fields up front (the credential isn't Sendable).
        let userIdentifier = credential.user
        // DUT-506: an empty / whitespace-only id is not a real sign-in — bail
        // before flipping `hasSession`, matching the Google side (DUT-285).
        guard !userIdentifier.isBlankAppleIdentifier else {
            // DUT-928 diagnostic (TEMPORARY): surface a normally-silent drop.
            onError?("Sign-in diagnostic: Apple returned an empty user id.")
            return
        }
        let displayName = AppleCredentialResolver.displayName(from: credential.fullName)
        let email = credential.email
        let authorizationCode = credential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }
        guard let profileStore, let onComplete else { return }
        let signIn = AppleProfileSignIn(profileStore: profileStore)
        Task { @MainActor in
            let outcome = await signIn.apply(
                userIdentifier: userIdentifier,
                displayName: displayName,
                email: email,
                authorizationCode: authorizationCode
            )
            onComplete(outcome)
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        activeController = nil
        retainedSelf = nil  // DUT-928 — end of flow; drop the in-flight retention.
        // DUT-928 diagnostic (TEMPORARY): the iPad flow completes Face ID but the
        // app never reflects a sign-in and shows NO error — so surface the RAW
        // error for EVERY code here, including `.canceled` / `.unknown` which
        // `userFacingErrorMessage` normally swallows as a user back-out. This tells
        // us exactly what the delegate receives on device. Revert to
        // `userFacingErrorMessage` once the root cause is identified.
        let nsError = error as NSError
        onError?("Sign-in diagnostic: error [\(nsError.domain) \(nsError.code)] \(nsError.localizedDescription)")
    }
}
#endif
