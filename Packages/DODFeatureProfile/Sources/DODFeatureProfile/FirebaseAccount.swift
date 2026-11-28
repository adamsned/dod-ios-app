#if canImport(UIKit)
import AuthenticationServices
import CryptoKit
import DODSupport
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UIKit

/// The Firebase account behind the profile sign-in. Signing in with Apple or
/// Google here also signs in to the Firebase project the Android app uses, so the
/// same person gets the same Firebase UID on both platforms and their saved
/// recipes sync through Firestore at `users/{uid}/saved/{recipeId}`.
///
/// A Firebase failure never blocks the profile sign-in itself; it only means
/// saved recipes don't sync with Android. Every call is a no-op until the app has
/// configured Firebase (`GoogleService-Info.plist` present).
public enum FirebaseAccount {

    /// Posted on the main thread just before account deletion removes the user's
    /// Firestore docs, so the saved-recipe listener stops first and doesn't remove
    /// this device's saves.
    public static let willDeleteNotification = Notification.Name("FirebaseAccount.willDelete")

    static var isConfigured: Bool { FirebaseApp.app() != nil }

    /// A nonce for a Sign in with Apple request: `raw` goes to Firebase, `hashed` to Apple.
    static func makeNonce() -> (raw: String, hashed: String) {
        let raw = UUID().uuidString + UUID().uuidString
        let hashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }

    static func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        await signIn(OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName))
    }

    /// Signs in with the account GoogleSignIn just signed in.
    static func signInWithCurrentGoogleUser() async {
        guard let tokens = try? await currentGoogleTokens(refresh: false) else { return }
        await signIn(GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken))
    }

    public static func signOut() {
        guard isConfigured else { return }
        try? Auth.auth().signOut()
    }

    /// Deletes the user's synced saved recipes and their Firebase account. Firebase
    /// only deletes an account right after a sign-in, so the user confirms with
    /// Apple (or Google, silently) first; if they cancel this throws and nothing is deleted.
    static func deleteAccount() async throws {
        guard isConfigured, let user = Auth.auth().currentUser else { return }
        try await user.reauthenticate(with: reauthCredential(for: user))
        await MainActor.run { NotificationCenter.default.post(name: willDeleteNotification, object: nil) }
        let firestore = Firestore.firestore()
        let saved = firestore.collection("users").document(user.uid).collection("saved")
        let docs = try await saved.getDocuments().documents
        for start in stride(from: 0, to: docs.count, by: 500) {  // Firestore's batch limit
            let batch = firestore.batch()
            docs[start..<min(start + 500, docs.count)].forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await user.delete()
    }

    /// True for a sign-in the user backed out of (no error to show).
    static func isCancellation(_ error: any Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
            || (error as NSError).domain == kGIDSignInErrorDomain
                && (error as NSError).code == GIDSignInError.canceled.rawValue
    }

    private static func signIn(_ credential: AuthCredential) async {
        guard isConfigured else { return }
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            DODLog.network.error(
                "Firebase sign-in failed; saved recipes won't sync with Android. error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private static func reauthCredential(for user: User) async throws -> AuthCredential {
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            let nonce = makeNonce()
            let idToken = try await AppleReauthentication().run(hashedNonce: nonce.hashed)
            return OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce.raw, fullName: nil)
        }
        guard let tokens = try await currentGoogleTokens(refresh: true) else {
            throw ASAuthorizationError(.invalidResponse)
        }
        return GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
    }

    /// The signed-in Google user's tokens; with `refresh`, restored from the
    /// Keychain if needed and refreshed so Firebase accepts them as a recent sign-in.
    @MainActor
    private static func currentGoogleTokens(refresh: Bool) async throws -> (idToken: String, accessToken: String)? {
        var user = GIDSignIn.sharedInstance.currentUser
        if refresh {
            if user == nil { user = try await GIDSignIn.sharedInstance.restorePreviousSignIn() }
            user = try await user?.refreshTokensIfNeeded()
        }
        guard let user, let idToken = user.idToken?.tokenString else { return nil }
        return (idToken, user.accessToken.tokenString)
    }
}

/// One Sign in with Apple prompt, for confirming account deletion.
@MainActor
private final class AppleReauthentication: NSObject {
    private var continuation: CheckedContinuation<String, any Error>?

    /// Returns the identity token.
    func run(hashedNonce: String) async throws -> String {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = hashedNonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation {
            continuation = $0
            controller.performRequests()
        }
    }
}

extension AppleReauthentication: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) {
            continuation?.resume(returning: idToken)
        } else {
            continuation?.resume(throwing: ASAuthorizationError(.invalidResponse))
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif
