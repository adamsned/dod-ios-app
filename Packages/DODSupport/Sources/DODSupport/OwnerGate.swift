import Foundation

/// **Daddy Mode (Phase 1, cosmetic).** The single gate that decides whether the
/// signed-in user is the app owner ("The Dutch Oven Daddy") and should therefore
/// see the owner-only *cosmetic* UI layer (the owner badge, the "Daddy status
/// confirmed" profile message, the "Daddy's Tools" placeholder row, the Feed
/// compose entry point, and their own Cook Rank on their comments).
///
/// **What this is — and is NOT.**
/// - The anchor is the **Sign in with Apple `sub`** — the stable, opaque Apple
///   user identifier (`ASAuthorizationAppleIDCredential.user`, persisted as
///   ``AppleAuthSession/userIdentifier``). It is **not a secret**: it identifies
///   an account but grants nothing on its own. Shipping it in the binary is fine.
/// - Phase 1 uses ``isOwner(_:)`` **only to REVEAL cosmetic UI**. It NEVER
///   authorizes a destructive action, a privileged write, or anything a
///   server would trust. Real enforcement (moderation, exclusive posting) is a
///   later backend phase that must verify the identity server-side. Treating a
///   client-side `sub` compare as an authorization boundary would be a security
///   bug — this gate deliberately does not do that.
///
/// **Safe by default.** ``ownerUserIdentifier`` ships as a clearly-marked
/// placeholder, so ``isOwner(_:)`` returns `false` for *everyone* — including
/// the owner — until the real value is filled in. Nothing owner-only renders for
/// any normal user. The real `sub` is captured **once** from Dad's signed-in
/// device (read ``AppleAuthSession/userIdentifier`` off his session and paste it
/// here) and only then does Daddy Mode light up for him alone.
public enum OwnerGate {

    /// The configured owner's Sign in with Apple `sub`.
    ///
    /// **Placeholder on purpose.** Until this is replaced with Dad's real `sub`,
    /// ``isOwner(_:)`` matches nobody — that is the intended safe default (Daddy
    /// Mode is invisible in the running app). Capture the real value once from
    /// his signed-in device (it looks like `001234.0a1b…c9.1234`) and paste it
    /// here to enable the cosmetic owner layer for him.
    ///
    /// Not a secret (see the type doc): it identifies an account but authorizes
    /// nothing on the client.
    ///
    /// Configured 2026-07-09 with the owner's real `sub`. Daddy Mode
    /// (Phase 1, cosmetic) is now live for this account only. (The one-off
    /// capture mechanism that read this value off his signed-in device has
    /// since been removed now that the value is configured.)
    public static let ownerUserIdentifier = "000180.c66be46df96a445d9987936216a97e66.1856"

    /// Whether `sub` identifies the configured app owner.
    ///
    /// Returns `false` for `nil`, empty / whitespace-only, or any `sub` that
    /// doesn't match ``ownerUserIdentifier`` — and, crucially, `false` for
    /// *everyone* while ``ownerUserIdentifier`` is still the unset placeholder,
    /// so the owner UI stays hidden until the real value is configured.
    ///
    /// The compare is length-independent-time-ish (fixed-cost fold over the
    /// bytes) — not a hard security guarantee (this gates cosmetics, not
    /// authorization), just an easy habit that avoids leaking a match via an
    /// early-return timing side channel.
    public static func isOwner(_ sub: String?) -> Bool {
        guard let sub else { return false }
        let candidate = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        // Unset placeholder ⇒ match nobody (the safe default).
        guard ownerUserIdentifier != placeholderIdentifier else { return false }
        return constantTimeEquals(candidate, ownerUserIdentifier)
    }

    /// Resolve the current signed-in session's `sub` from the on-device store
    /// and return whether it belongs to the owner. Defaults to the production
    /// ``KeychainAppleAuthSessionStore`` — the same store the rest of the app
    /// loads the session through — so callers get "is the *current* user the
    /// owner?" without wiring a store themselves. A read failure or no session
    /// ⇒ `false`.
    public static func isCurrentUserOwner(
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore()
    ) -> Bool {
        let sub = (try? sessionStore.load())?.userIdentifier
        return isOwner(sub)
    }

    /// The sentinel placeholder value ``ownerUserIdentifier`` holds until it's
    /// configured with the real `sub`.
    static let placeholderIdentifier = "REPLACE_WITH_DADS_SIWA_SUB"

    /// Fixed-cost byte compare (no early return on the first mismatch). Unequal
    /// lengths are still `false`, but the equal-length path folds every byte.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        var difference: UInt8 = 0
        for index in lhsBytes.indices {
            difference |= lhsBytes[index] ^ rhsBytes[index]
        }
        return difference == 0
    }
}
