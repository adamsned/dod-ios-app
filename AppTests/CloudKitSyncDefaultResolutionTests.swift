import DODPersistence
import XCTest

@testable import DODApp

/// L1 unit coverage for `DODApp.resolveCloudKitSyncDefault(in:)` — the one-time
/// rule that decides whether iCloud Sync starts ON.
///
/// This is worth pinning hard: the flag it writes decides whether a user's saved
/// recipes leave the device, it runs exactly once per install (so a wrong answer
/// is sticky), and the branch that matters most — an explicit decline surviving
/// an upgrade — fails silently and invisibly. Each test uses an isolated
/// `UserDefaults` suite so nothing here can touch `.standard`.
final class CloudKitSyncDefaultResolutionTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    private var syncKey: String { RecipeStore.cloudKitSyncOptInKey }
    private var onboardingKey: String { RootView.onboardingCompletedKey }

    override func setUp() {
        super.setUp()
        suiteName = "dod.tests.syncDefault.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// A brand-new install (onboarding not completed) is the ONLY population that
    /// defaults ON — it's the one that sees the welcome screen's disclosure.
    func test_freshInstall_defaultsSyncOn() {
        DODApp.resolveCloudKitSyncDefault(in: defaults)

        XCTAssertTrue(
            defaults.bool(forKey: syncKey),
            "a fresh install should default iCloud Sync ON"
        )
    }

    /// THE important one. An upgrader who explicitly declined has the key already
    /// set to `false`; the rule must never touch it. If this regresses, their cook
    /// journal and photos start uploading against a choice they actually made.
    func test_explicitDecline_survivesUpgrade() {
        defaults.set(true, forKey: onboardingKey)
        defaults.set(false, forKey: syncKey)

        DODApp.resolveCloudKitSyncDefault(in: defaults)

        XCTAssertFalse(
            defaults.bool(forKey: syncKey),
            "an explicit decline must be honored, never silently flipped on"
        )
    }

    /// An existing user who was never asked (key unset, onboarding done) is left
    /// OFF — they never saw a disclosure, so switching them on would be the exact
    /// silent-upload surprise this rule exists to avoid.
    func test_existingUserNeverAsked_staysOff() {
        defaults.set(true, forKey: onboardingKey)

        DODApp.resolveCloudKitSyncDefault(in: defaults)

        XCTAssertFalse(
            defaults.bool(forKey: syncKey),
            "an established user who was never asked should not be switched on"
        )
    }

    /// An explicit opt-in is likewise left alone (the guard is about the key being
    /// SET, not about its value).
    func test_explicitOptIn_isPreserved() {
        defaults.set(true, forKey: onboardingKey)
        defaults.set(true, forKey: syncKey)

        DODApp.resolveCloudKitSyncDefault(in: defaults)

        XCTAssertTrue(defaults.bool(forKey: syncKey), "an explicit opt-in must be preserved")
    }

    /// Idempotent: it runs on EVERY launch, so the second run must not re-derive
    /// (and thus must not overwrite a Settings change made after the first).
    func test_isIdempotent_andDoesNotClobberALaterSettingsChange() {
        // First launch: fresh install → ON.
        DODApp.resolveCloudKitSyncDefault(in: defaults)
        XCTAssertTrue(defaults.bool(forKey: syncKey))

        // The user finishes onboarding, then turns sync OFF in Settings.
        defaults.set(true, forKey: onboardingKey)
        defaults.set(false, forKey: syncKey)

        // Next launch must leave that alone rather than re-deriving a default.
        DODApp.resolveCloudKitSyncDefault(in: defaults)

        XCTAssertFalse(
            defaults.bool(forKey: syncKey),
            "a Settings opt-out must not be clobbered by a later launch"
        )
    }
}
