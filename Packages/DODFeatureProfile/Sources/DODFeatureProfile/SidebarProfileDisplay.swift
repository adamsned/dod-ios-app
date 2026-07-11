import DODSupport

/// DUT-940 — resolves the iPad sidebar profile row's title/subtitle,
/// preferring the locally-saved ``UserProfile`` and falling back to the
/// persisted ``AppleAuthSession`` field-by-field. Pure and unit-testable so
/// `SidebarProfileRow` (App target) stays a thin view.
///
/// Apple only returns `displayName`/`email` on the credential from the
/// **very first** authorization for an Apple ID (DUT-16); every subsequent
/// re-auth returns a session with those fields `nil`. DUT-936 first
/// distinguished a signed-in-no-name user from a true guest, but it still
/// showed a generic "Signed In" even when the session itself carried a real
/// name or email (Apple provided one on the first authorization, but no
/// profile was ever saved). This fix (DUT-940) resolves the name and the
/// email *independently*, each preferring `profile` and falling back to
/// `session`, so a signed-in user's actual name/email surfaces whenever
/// either source has one.
///
/// Resolution, in priority order:
/// 1. A (trimmed, non-blank) name exists — from `profile` first, else
///    `session` — → the name as the title, with the subtitle set to the
///    resolved email (profile's, else session's) if one exists, else
///    "View profile" (a saved profile with no email yet) or "Add your
///    email" (no profile at all — the name came from the session).
/// 2. Else a (trimmed, non-blank) email exists — from `profile` first, else
///    `session` — → the email as the title + "Add your name".
/// 3. Else a `session` exists (signed in, no name or email yet) → "Signed
///    In" + a prompt to add a name and photo.
/// 4. Else (no session, no profile — a true guest) → "Set Up Your Profile".
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
        let name = firstNonBlank(profile?.displayName, session?.displayName)
        let email = firstNonBlank(profile?.email, session?.email)
        let signedIn = session != nil

        if let name {
            return (name, email ?? (profile != nil ? "View profile" : "Add your email"))
        } else if let email {
            return (email, "Add your name")
        } else if signedIn {
            return ("Signed In", "Add your name and photo")
        } else {
            return ("Set Up Your Profile", "Add Your Name and Photo")
        }
    }

    /// Returns the first of `values` that is non-`nil` and non-blank after
    /// trimming whitespace/newlines — the shared "is this candidate usable?"
    /// test for both the name and email resolution above.
    private static func firstNonBlank(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
