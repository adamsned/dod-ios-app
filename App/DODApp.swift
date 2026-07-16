import BackgroundTasks
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import SwiftUI
import UserNotifications

@main
struct DODApp: App {

    /// Assigned explicitly in `init()` rather than via a default value, because
    /// ORDER MATTERS: `AppDependencies.init` builds the SwiftData
    /// `ModelContainer`, and whether that container is CloudKit-backed is read
    /// from `RecipeStore.cloudKitSyncOptInKey` at construction time. A default
    /// property value would be evaluated BEFORE the `init()` body runs, so the
    /// container would be built against an unresolved flag. The launch
    /// overrides + the sync default must both be settled first.
    @State private var dependencies: AppDependencies
    /// Installs the `UNUserNotificationCenterDelegate` at launch (US-42 /
    /// AC-42.3 + AC-42.5). A SwiftUI `App` has no `application(_:didFinish…)`
    /// hook, so the delegate adaptor bridges UIKit's launch callback where
    /// the notification-center delegate must be set before any notification
    /// is delivered.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 1. Launch overrides first — they can clear/set the onboarding flag the
        //    sync default is derived from.
        Self.applyTestLaunchOverrides()
        // 2. Resolve the iCloud-Sync default while nothing has read it yet.
        Self.resolveCloudKitSyncDefaultIfNeeded()
        // 3. Only now build the composition root (and with it the container).
        _dependencies = State(initialValue: AppDependencies())
    }

    /// One-time resolution of the iCloud-Sync opt-in default (fresh installs ON).
    ///
    /// `RecipeStore.cloudKitSyncOptIn(in:)` is a plain `defaults.bool(...)`, so an
    /// unset key reads `false`. Rather than change that read (the container logic
    /// and the DUT-630 simulator guard both depend on its exact semantics), we
    /// materialize the key ONCE, here, before anything reads it.
    ///
    /// The gate is deliberately narrow — only a genuinely fresh install defaults
    /// ON, disclosed by the welcome screen's iCloud bullet (which replaced the
    /// old "Turn On iCloud Sync?" alert):
    ///
    /// - **Fresh install** (onboarding not completed) → ON.
    /// - **Existing user who explicitly declined** → the key is already set to
    ///   `false`; the `object(forKey:) == nil` guard means we never touch it, so
    ///   their decline is honored.
    /// - **Existing user who was never asked** (key unset, onboarding done) → left
    ///   OFF rather than silently switched on. Flipping sync on for an established
    ///   user without their say-so is exactly the surprise we're avoiding.
    ///
    /// Idempotent: writes only when the key is unset, so it's a no-op on every
    /// launch after the first. Settings remains the way to change it.
    private static func resolveCloudKitSyncDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: RecipeStore.cloudKitSyncOptInKey) == nil else { return }
        let isFreshInstall = !defaults.bool(forKey: RootView.onboardingCompletedKey)
        defaults.set(isFreshInstall, forKey: RecipeStore.cloudKitSyncOptInKey)
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
    private static func applyTestLaunchOverrides() {
        let args = CommandLine.arguments
        let env = ProcessInfo.processInfo.environment
        if env["DOD_SUPPRESS_ONBOARDING"] == "1" {
            UserDefaults.standard.set(true, forKey: RootView.onboardingCompletedKey)
        }
        if args.contains("-DODForceFreshOnboarding") {
            UserDefaults.standard.removeObject(forKey: RootView.onboardingCompletedKey)
            // The onboarding UI test dismisses the welcome sheet; suppress the
            // first-run permission prompts so the system dialogs don't block it.
            DODEnvironment.suppressFirstRunPrompts = true
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
            // T-610: the comment-moderation store (DUT-501) persists blocked
            // authors + reported comment ids in `UserDefaults.standard`, which
            // survives relaunch on a shared simulator. Clear it at E2E launch so
            // the report/block journey starts from a clean, deterministic slate
            // (mirrors the in-memory store the E2E network stub already uses).
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "dod.moderation.blockedAuthorsV1")
            defaults.removeObject(forKey: "dod.moderation.hiddenCommentIDsV1")
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

    /// True when the first-run permission prompts (notifications + iCloud Sync,
    /// shown after the welcome sheet) must be suppressed — set when the host is
    /// the onboarding UI test (`-DODForceFreshOnboarding`), which dismisses the
    /// welcome sheet but must not trip the system permission dialogs. Production
    /// launches (no flag) leave this false, so real new installs get the prompts.
    nonisolated(unsafe) static var suppressFirstRunPrompts: Bool = false
}

/// UIKit application delegate bridged into the SwiftUI lifecycle via
/// `@UIApplicationDelegateAdaptor` (see `DODApp`). Two jobs:
///
/// 1. Install the `UNUserNotificationCenterDelegate` at launch so tapped
///    local notifications route their deep link (US-42 / AC-42.3) and
///    foreground notifications surface a banner (AC-42.5).
/// 2. DUT-938 — register + (re)schedule the `BGAppRefreshTask` that is the
///    missing TRIGGER for new-post notifications: the notification
///    infrastructure above already existed, but nothing ever detected a
///    new post and called `NotificationService.scheduleNewPostNotification`.
///    `NewPostsPoller` is that trigger; this delegate is only the OS-level
///    plumbing that wakes it up periodically.
///
/// The `NotificationCoordinator` is retained here for the process lifetime
/// — `UNUserNotificationCenter.delegate` is a `weak` reference, so a
/// non-retained coordinator would be deallocated and tap routing would
/// silently stop working.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Must exactly match the `BGTaskSchedulerPermittedIdentifiers` entry in
    /// `project.yml` (the source of truth `xcodegen generate` writes into
    /// `Info.plist`) — a mismatch makes `register(forTaskWithIdentifier:)`
    /// silently refuse the task at runtime.
    static let newPostsTaskIdentifier = "com.dutchovendaddy.DODApp.newposts"

    /// BGAppRefreshTask is opportunistic (iOS decides the real cadence from
    /// battery, Background App Refresh settings, and usage patterns) — this
    /// is only the EARLIEST the next refresh may run, not a guarantee.
    private static let refreshInterval: TimeInterval = 4 * 60 * 60

    private let notificationCoordinator = NotificationCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationCoordinator
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.newPostsTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handleNewPostsRefresh(refreshTask)
        }
        scheduleAppRefresh()
        return true
    }

    /// Also re-arms the next refresh every time the app backgrounds — the OS
    /// discards a pending request once its task runs, so re-submitting here
    /// (in addition to at launch) keeps the chain alive across sessions that
    /// never get killed-and-relaunched.
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }

    /// Submits (or re-submits) the next opportunistic new-posts refresh.
    /// `BGTaskScheduler` de-dupes by identifier, so calling this from both
    /// launch and backgrounding never double-books a task.
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.newPostsTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            DODLog.app.error("BGAppRefreshTask submit failed: \(String(describing: error))")
        }
    }

    /// Runs the poll, reschedules the NEXT refresh immediately (so an
    /// expired/killed run doesn't silently end the chain), and reports
    /// completion back to the OS. `expirationHandler` cancels the in-flight
    /// poll if iOS revokes background time before it finishes.
    private func handleNewPostsRefresh(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()
        // Fresh, lightweight `WPRestClient` + `NotificationService` rather
        // than a full `AppDependencies()` — this handler can run in a
        // background-launched process with no SwiftUI scene, and the
        // composition root's SwiftData/CloudKit setup is unrelated to
        // fetching + notifying about new posts. `AppDependencies.makeHTTPClient()`
        // is reused so this still respects the E2E stub swap (no live
        // network calls under the L5 harness) — the exact seam
        // `AppDependencies.init` uses for `restClient`.
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: AppDependencies.makeHTTPClient()),
            notificationService: NotificationService()
        )
        let pollTask = Task {
            await poller.poll()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            pollTask.cancel()
        }
    }
}
