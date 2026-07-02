import Foundation

/// Pure resolution of a fresh **Sign in with Apple** credential into the
/// ``AppleAuthSession`` to persist (US-46 / DUT-16 Phase a). This is the
/// correctness-critical half of the auth coordinator (AC-46.2) — the part that
/// has to get Apple's "name + email only on the first authorization" quirk
/// right — kept here as **pure Foundation** so it is fully unit-tested without
/// `AuthenticationServices` or a live Apple sheet. The coordinator (a later
/// slice) is then a thin `ASAuthorizationController` adapter that calls these.
///
/// Spec trace: US-46 / AC-46.1 (the dumb store) + AC-46.2 (the coordinator-side
/// merge this implements), CL-189.
public enum AppleCredentialResolver {

    /// Format `ASAuthorizationAppleIDCredential.fullName` (a
    /// `PersonNameComponents`) into a display string. Returns `nil` for a `nil`
    /// or effectively-empty value — Apple withholds the name on every sign-in
    /// after the first, handing back empty components rather than a name.
    public static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(
            from: components,
            style: .default
        )
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Resolve the session to persist from a fresh credential, **carrying the
    /// name/email forward** from `existing` only when both hold:
    ///
    /// 1. the credential omits them (Apple releases them once, on first auth), and
    /// 2. it's the **same** Apple user — a different `userIdentifier` must never
    ///    inherit the prior user's name/email (e.g. a second person signing in
    ///    on a shared device after the first signed out).
    ///
    /// The credential's values always win when present (a user who re-enabled
    /// name/email sharing in Settings → Apple ID gets the fresh values). The
    /// `userIdentifier` from the new credential is authoritative.
    ///
    /// DUT-375: the `refreshToken` is likewise carried forward from `existing`
    /// on a same-user re-auth (Apple's `ASAuthorizationAppleIDCredential` never
    /// re-issues it — it's only ever delivered to the server-side token exchange,
    /// not this client credential — so dropping it here logged the user back out
    /// of the token-backed flows). A different `userIdentifier` nils it, same as
    /// name/email, so a second person on a shared device can't inherit it.
    public static func resolve(
        userIdentifier: String,
        credentialDisplayName: String?,
        credentialEmail: String?,
        existing: AppleAuthSession?
    ) -> AppleAuthSession {
        let sameUser = existing?.userIdentifier == userIdentifier
        let name = credentialDisplayName ?? (sameUser ? existing?.displayName : nil)
        let email = credentialEmail ?? (sameUser ? existing?.email : nil)
        let refreshToken = sameUser ? existing?.refreshToken : nil
        return AppleAuthSession(
            userIdentifier: userIdentifier,
            displayName: name,
            email: email,
            refreshToken: refreshToken
        )
    }
}
