import Foundation
import Testing

@testable import DODApp

/// Regression coverage for the DUT-400 migration gate-ordering bug fixed in
/// `RootView.shouldMigrateFirstRunFlags(in:)`.
///
/// Before the fix, `migrateFirstRunFlagsIfNeeded()` treated ANY install with
/// `onboardingCompletedKey == true` and `firstRunPromptsCompletedKey == nil`
/// as a pre-DUT-280 legacy upgrade and stamped `firstRunPromptsCompletedKey`
/// true unconditionally. But that exact state is ALSO what a brand-new,
/// fully-current install looks like the instant a user taps the onboarding
/// CTA and then kills the app before either first-run prompt (notifications,
/// iCloud Sync) resolves — the precise case DUT-280's independent
/// `firstRunPromptsCompletedKey` recovery flag exists to catch. The old code
/// silently defeated that recovery: the prompts would never be asked again.
/// `firstRunPromptsArmedKey`, set synchronously the moment onboarding
/// completes under current code, disambiguates the two cases.
///
/// Each test uses its own throwaway `UserDefaults(suiteName:)` so runs never
/// leak state into each other or into `.standard`.
@Suite("RootView.shouldMigrateFirstRunFlags")
struct RootViewOnboardingMigrationTests {

    private func isolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "RootViewOnboardingMigrationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("failed to create isolated UserDefaults suite")
            return (.standard, suiteName)
        }
        return (defaults, suiteName)
    }

    @Test("a brand-new install with no keys set at all does not migrate")
    func freshInstall_doesNotMigrate() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(!RootView.shouldMigrateFirstRunFlags(in: defaults))
    }

    @Test("a genuinely legacy pre-DUT-280 install migrates")
    func legacyPreDUT280Install_migrates() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Onboarded before `firstRunPromptsCompletedKey` (and the armed flag
        // that disambiguates it) ever existed.
        defaults.set(true, forKey: RootView.onboardingCompletedKey)

        #expect(RootView.shouldMigrateFirstRunFlags(in: defaults))
    }

    @Test("THE FIX: a current install killed after onboarding but before first-run prompts resolve does not migrate")
    func killedMidFirstRunSetup_doesNotMigrate() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Mirrors `onboardingCover.onFinish`: both keys are set synchronously
        // at CTA-tap time, before the async notification/iCloud-Sync prompts
        // have a chance to run — then the app is killed.
        defaults.set(true, forKey: RootView.onboardingCompletedKey)
        defaults.set(true, forKey: RootView.firstRunPromptsArmedKey)

        // Before the fix this returned true, permanently defeating the
        // DUT-280 recovery for this install.
        #expect(!RootView.shouldMigrateFirstRunFlags(in: defaults))
    }

    @Test("an install that already finished first-run prompts does not re-migrate")
    func firstRunPromptsAlreadyCompleted_doesNotMigrate() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: RootView.onboardingCompletedKey)
        defaults.set(true, forKey: RootView.firstRunPromptsArmedKey)
        defaults.set(true, forKey: RootView.firstRunPromptsCompletedKey)

        #expect(!RootView.shouldMigrateFirstRunFlags(in: defaults))
    }

    @Test("onboarding not yet completed never migrates, even with a stray armed flag")
    func onboardingNotCompleted_doesNotMigrate() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // onboardingCompletedKey deliberately left unset (`bool(forKey:)`
        // defaults to false); a stray armed flag must not force a migration.
        defaults.set(true, forKey: RootView.firstRunPromptsArmedKey)

        #expect(!RootView.shouldMigrateFirstRunFlags(in: defaults))
    }
}
