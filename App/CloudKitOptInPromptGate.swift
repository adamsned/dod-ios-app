import DODPersistence
import Foundation

/// Once-only gate for the first-launch iCloud-Sync opt-in prompt
/// (US-41 / AC-41.2, T-704). Extracted from `RootView` so the "show it
/// exactly once, ever" rule is unit-testable without a SwiftUI host — the
/// same factoring `RecipeRouteResolver` applies to RootView's deep-link
/// policy.
///
/// The gate owns ONLY the *prompt-shown* flag (`dod.cloudKitSyncOptInPromptShownV1`).
/// The actual sync opt-in lives behind `RecipeStore.cloudKitSyncOptInKey`
/// (written via the `SettingsDependencies` seam when the user taps "Turn on
/// iCloud Sync") — a user who taps "Not now" still flips *this* flag so the
/// sheet never returns, while re-enabling later stays the Settings toggle's
/// job (AC-41.3). Keeping the two flags separate is exactly AC-41.2's contract.
struct CloudKitOptInPromptGate {

    /// Net-new UserDefaults flag (AC-41.2 / AC-41.11). `true` once the prompt
    /// has been shown + dismissed via either button; the sheet never appears
    /// again. The `V1` suffix mirrors `dod.onboardingCompletedV1` and
    /// `dod.cloudkit.syncOptInV1` so a future re-prompt can bump the version
    /// rather than reading the old key.
    static let promptShownKey = "dod.cloudKitSyncOptInPromptShownV1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True only when the prompt has never been shown — the sole condition
    /// under which AC-41.2's sheet appears. Reads `false` for an absent key
    /// (the documented first-launch state) so a fresh install shows it once.
    var shouldShow: Bool {
        !defaults.bool(forKey: Self.promptShownKey)
    }

    /// Record that the prompt has been shown. Both the primary ("Turn on
    /// iCloud Sync") and secondary ("Not now") actions call this so neither
    /// path ever re-prompts.
    func markShown() {
        defaults.set(true, forKey: Self.promptShownKey)
    }
}
