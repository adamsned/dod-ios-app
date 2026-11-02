import Testing

@testable import DODFeatureFeed

/// DUT-972 — pins the persisted UserDefaults key strings for the weeknight
/// streak nudge. These values are persisted contracts; do not rename them.
@Suite("Streak nudge settings keys (DUT-972)")
struct StreakNudgeSettingsKeyTests {
    @Test func streakNudgeKeysAreStable() {
        #expect(SettingsViewModel.streakNudgesEnabledKey == "dod.settings.streakNudgesEnabled")
        #expect(SettingsViewModel.streakNudgeLastSentKey == "dod.settings.streakNudgeLastSent")
    }
}
