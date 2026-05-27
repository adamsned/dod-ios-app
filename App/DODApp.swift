import Foundation
import SwiftUI

@main
struct DODApp: App {

    @State private var dependencies = AppDependencies()

    init() {
        applyTestLaunchOverrides()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }

    /// UI-test escape hatches. Each flag here exists so XCUITests can put the
    /// app into a known state without uninstalling between runs (which Xcode
    /// won't do reliably on Simulator).
    ///
    /// - `-DODForceFreshOnboarding` (launch argument): clear the
    ///   onboarding-completed flag so the welcome sheet is shown on the next
    ///   launch. Used by `SmokeTests.test_onboardingShowsOnFirstLaunchAndDismisses`.
    /// - `DOD_SUPPRESS_ONBOARDING=1` (environment): force the flag to true so
    ///   the welcome sheet does NOT appear. Used in `SmokeTests.setUp` so
    ///   every other smoke test boots straight into the tab bar.
    /// - `-DOD_E2E_MODE=1` (launch argument) **or** `DOD_E2E_MODE=1`
    ///   (environment): signals that the host process is being driven by the
    ///   L5 `DODAppE2ETests` scheme. Phase 1 (T-602): the flag is recorded
    ///   into `DODEnvironment.isE2EMode` but does NOT yet swap dependencies
    ///   — the seed journeys in T-603 drive against the production code paths
    ///   the same way today's L3 smoke does. Phase 2 (T-610 follow-up): wire
    ///   a `FakeAppDependencies` that reads `DODEnvironment.isE2EMode` and
    ///   returns canned fixtures so the suite runs hermetically. Spec trace:
    ///   AC-T5 / CL-58.
    ///
    /// The override flag wins if both are set (you said you wanted a fresh
    /// onboarding more recently).
    private func applyTestLaunchOverrides() {
        let args = CommandLine.arguments
        let env = ProcessInfo.processInfo.environment
        if env["DOD_SUPPRESS_ONBOARDING"] == "1" {
            UserDefaults.standard.set(true, forKey: RootView.onboardingCompletedKey)
        }
        if args.contains("-DODForceFreshOnboarding") {
            UserDefaults.standard.removeObject(forKey: RootView.onboardingCompletedKey)
        }
        // L5 E2E mode flag — recorded process-wide so T-610's future
        // FakeAppDependencies switch can read it without re-parsing args.
        // Today (Phase 1) the boolean is read by zero consumers; the journeys
        // run against the live blog the same way the L3 smoke does. Spec
        // trace: AC-T5 / CL-58.
        if args.contains("-DOD_E2E_MODE=1") || env["DOD_E2E_MODE"] == "1" {
            DODEnvironment.isE2EMode = true
        }
    }
}

/// Process-wide flags set at launch by `DODApp.applyTestLaunchOverrides()`.
/// Consumed (in the future) by `FakeAppDependencies` to swap canned fixtures
/// into the composition root when the L5 E2E suite is driving the host.
///
/// Today the only flag is `isE2EMode` and it has no production consumers —
/// the host runs identically whether the flag is set or not. T-610 wires the
/// fake-dependencies switch that actually reads this value. Spec trace: AC-T5
/// / CL-58.
enum DODEnvironment {

    /// True when the host process was launched with `-DOD_E2E_MODE=1` (launch
    /// arg) or `DOD_E2E_MODE=1` (environment). Set once at app init; never
    /// mutated by production code. T-610 will read this from
    /// `FakeAppDependencies` to decide whether to swap fixtures into the
    /// composition root.
    nonisolated(unsafe) static var isE2EMode: Bool = false
}
