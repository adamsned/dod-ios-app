import DODSupport

/// DUT-935 — resolves the iPad sidebar profile row's title/subtitle for three
/// states, pure and unit-testable so `SidebarProfileRow` (App target) stays a
/// thin view.
///
/// Apple only returns `displayName`/`email` on the credential from the
/// **very first** authorization for an Apple ID (DUT-16); every subsequent
/// re-auth returns a session with those fields `nil`. Before this fix, a
/// signed-in user with no locally-saved profile name saw the same
/// "Set Up Your Profile" copy as a true guest — this resolver distinguishes
/// the two by also considering whether a session exists.
///
/// Cases, in priority order:
/// 1. `profile` has a non-empty (trimmed) `displayName` → the name + "View profile".
/// 2. Else a `session` exists (signed in, no name yet) → "Signed In" + a prompt
///    to add a name and photo.
/// 3. Else (no session, no profile — a true guest) → "Set Up Your Profile".
public enum SidebarProfileDisplay {

    /// - Parameters:
    ///   - profile: The locally-saved profile, if any.
    ///   - session: The persisted Apple/Google auth session, if any (`nil` means
    ///     the user has never signed in — a guest).
    /// - Returns: The row's title and subtitle for the current state.
    public static func resolve(
        profile: UserProfile?,
        session: AppleAuthSession?
    ) -> (title: String, subtitle: String) {
        if let profile, !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (profile.displayName, "View profile")
        } else if session != nil {
            return ("Signed In", "Add your name and photo")
        } else {
            return ("Set Up Your Profile", "Add Your Name and Photo")
        }
    }
}
