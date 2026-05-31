import XCTest

@testable import DODApp

/// L1 unit coverage for `CloudKitOptInPromptGate` — the once-only gate for the
/// first-launch iCloud-Sync opt-in prompt (US-41 / AC-41.2, T-704). Pins the
/// "show exactly once, ever" contract without standing up a SwiftUI host
/// (mirrors how `RecipeRouteResolverTests` exercises RootView's deep-link
/// policy in isolation).
final class CloudKitOptInPromptGateTests: XCTestCase {

    /// Fresh, per-test `UserDefaults` suite so one test's write never leaks
    /// into another (mirrors `SettingsViewModelTests.isolatedDefaults`).
    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "CloudKitOptInPromptGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// AC-41.2: a fresh install (flag absent) shows the prompt — `shouldShow`
    /// reads `false` for the missing key and inverts to `true`.
    func test_shouldShowIsTrueOnFreshDefaults() {
        let gate = CloudKitOptInPromptGate(defaults: isolatedDefaults())
        XCTAssertTrue(gate.shouldShow)
    }

    /// AC-41.2 / AC-41.11: once shown (either button calls `markShown`), the
    /// sheet never returns — and the suppression is persisted, not in-memory,
    /// so a relaunch (a fresh gate over the same suite) still hides it.
    func test_markShownSuppressesAndPersists() {
        let defaults = isolatedDefaults()
        let gate = CloudKitOptInPromptGate(defaults: defaults)

        gate.markShown()

        XCTAssertFalse(gate.shouldShow)
        XCTAssertTrue(defaults.bool(forKey: CloudKitOptInPromptGate.promptShownKey))
        XCTAssertFalse(CloudKitOptInPromptGate(defaults: defaults).shouldShow)
    }

    /// An already-true flag (an upgrader who saw the prompt on a prior launch,
    /// or the UI-test suppression in `DODApp.applyTestLaunchOverrides`) keeps
    /// the prompt hidden.
    func test_preExistingShownFlagHidesPrompt() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: CloudKitOptInPromptGate.promptShownKey)
        XCTAssertFalse(CloudKitOptInPromptGate(defaults: defaults).shouldShow)
    }
}
