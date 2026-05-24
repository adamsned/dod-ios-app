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
    }
}
