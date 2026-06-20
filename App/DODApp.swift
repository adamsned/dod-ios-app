import Foundation
import SwiftUI
import UserNotifications

@main
struct DODApp: App {

    @State private var dependencies = AppDependencies()
    /// Installs the `UNUserNotificationCenterDelegate` at launch (US-42 /
    /// AC-42.3 + AC-42.5). A SwiftUI `App` has no `application(_:didFinish…)`
    /// hook, so the delegate adaptor bridges UIKit's launch callback where
    /// the notification-center delegate must be set before any notification
    /// is delivered.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// DUT-15 / T-787 — drives the background-poll re-arm: the next
    /// `BGAppRefreshTask` request is submitted whenever the app backgrounds.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        applyTestLaunchOverrides()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .onChange(of: scenePhase) { _, phase in
                    // DUT-15 / T-787 — re-arm the next background poll whenever
                    // the app backgrounds. Each task run also re-arms the next.
                    if phase == .background {
                        appDelegate.backgroundRefreshService.scheduleNext()
                    }
                }
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
        // T-762 / CL-159 (DUT-68): the first-launch iCloud-Sync opt-in sheet was
        // removed (sync opt-in now lives only in Settings), so the
        // `-DODForceCloudKitOptInPrompt` / prompt-shown launch overrides that
        // kept it out of the UI-test golden paths are gone too.
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

/// UIKit application delegate bridged into the SwiftUI lifecycle via
/// `@UIApplicationDelegateAdaptor` (see `DODApp`). Its sole job in v1 is to
/// install the `UNUserNotificationCenterDelegate` at launch so tapped
/// local notifications route their deep link (US-42 / AC-42.3) and
/// foreground notifications surface a banner (AC-42.5).
///
/// The `NotificationCoordinator` is retained here for the process lifetime
/// — `UNUserNotificationCenter.delegate` is a `weak` reference, so a
/// non-retained coordinator would be deallocated and tap routing would
/// silently stop working.
final class AppDelegate: NSObject, UIApplicationDelegate {

    private let notificationCoordinator = NotificationCoordinator()
    /// DUT-15 / T-787 — owns the best-effort new-post background poll for the
    /// process lifetime. `register(...)` runs synchronously below (the
    /// BGTaskScheduler contract); the SwiftUI scene re-arms the next request on
    /// background, and each run re-arms the one after.
    let backgroundRefreshService = BackgroundRefreshService(notificationService: NotificationService())

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationCoordinator
        // DUT-15 / T-787 — register the BGAppRefreshTask handler before launch
        // finishes (required by BGTaskScheduler). The first request is armed
        // when the scene first backgrounds.
        backgroundRefreshService.register()
        return true
    }
}
