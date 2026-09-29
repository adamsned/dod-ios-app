import Foundation

// ============================================================================
// ⚠️ DEV DEBUG — STRIP BEFORE ANY PUBLIC RELEASE ⚠️
//
// This whole file, the Settings "Dev Debug" section that renders it, and the
// force-show gates that read `forceShowOwnerUI` are DEVELOPER-ONLY (Dad +
// Spencer, internal TestFlight channel). They MUST be removed before a public
// TestFlight or App Store release of v2. To strip: delete this file, the
// `devDebugSection` + version-footer long-press unlock in `SettingsView`, and
// the `|| DevDebug.forceShowOwnerUI()` clauses at the two owner-UI gates
// (grep `DevDebug`). Everything is isolated so removal is a few deletions.
// (Claude will refuse to help ship a public build while this exists.)
// ============================================================================

/// Developer-only debug flags for quick, in-app UI/perf toggling on the
/// internal (Dad + Spencer) TestFlight channel. Not gated by account — the
/// Settings section is revealed by a hidden long-press on the version footer
/// (or automatically for the configured owner), which is enough for a control
/// surface that never ships to the public (see the strip note above).
public enum DevDebug {

    /// `UserDefaults` key: whether the hidden Dev Debug section has been
    /// unlocked (toggled by long-pressing the Settings version footer).
    public static let unlockedKey = "dod.devdebug.unlocked"

    /// `UserDefaults` key: force-show the cosmetic owner ("Daddy's Tools") UI
    /// on any account, so non-owner dev accounts can review the icons/design.
    /// Reveals the UI only — it does NOT grant owner actions (those stay gated
    /// on `OwnerGate.isCurrentUserOwner()`).
    public static let forceShowOwnerUIKey = "dod.devdebug.forceShowOwnerUI"

    /// Whether the Dev Debug section has been unlocked on this device.
    public static func isUnlocked(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: unlockedKey)
    }

    /// Whether to force-show the cosmetic owner UI for design review.
    public static func forceShowOwnerUI(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: forceShowOwnerUIKey)
    }
}
