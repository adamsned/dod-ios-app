import BackgroundTasks
import DODDomain
import DODFeatureFeed
import DODNetworking
import DODSupport
import Foundation

/// DUT-15 / T-787 — best-effort background poll for newly published posts.
///
/// iOS wakes the app on its own schedule via a `BGAppRefreshTask`; this service
/// asks the WordPress feed for the single newest post id and, when it is newer
/// than the last one we acted on, fires the existing US-42 local new-post
/// notification through ``NotificationService`` (which still self-gates on the
/// Settings toggle + OS authorization). It is the *only* background fetch the
/// app performs — the NFR-3 carve-out granted by CL-183.
///
/// **Best-effort, not real-time.** iOS throttles `BGAppRefreshTask` by usage,
/// battery, and Low Power Mode, and never runs it for a force-quit app, so a
/// "new post" alert is delayed (often substantially) and can be missed
/// entirely. That is a documented limitation of the no-server approach, not a
/// bug. The instant, reliable alternative is a server push (OneSignal / APNs),
/// deferred per the DUT-15 owner decision.
///
/// All state is process-shared (`UNUserNotificationCenter`,
/// `UserDefaults.standard`), so a fresh instance behaves identically to any
/// other — the `AppDelegate` owns one for the process lifetime. The pure
/// "should we notify" decision lives in ``NewPostPollDecision`` (DODFeatureFeed)
/// and is unit-tested there; this orchestrator is a thin I/O shell.
///
/// `@unchecked Sendable`: every stored property is an immutable reference to a
/// thread-safe / process-shared service (`UserDefaults` is thread-safe;
/// `NotificationService` is `@MainActor`-isolated and only ever touched via
/// `await`), so the service is safe to hand to the off-main BGTask launch
/// handler.
final class BackgroundRefreshService: @unchecked Sendable {

    /// Must exactly match the `BGTaskSchedulerPermittedIdentifiers` entry in
    /// project.yml, or `register` throws at runtime.
    static let taskIdentifier = "com.dutchovendaddy.DODApp.newpost-refresh"

    private static let lastSeenKey = "dod.background.lastSeenPostID"
    /// ~1h floor; iOS chooses the actual (later) run time.
    private static let earliestInterval: TimeInterval = 60 * 60

    private let restClient: WPRestClient
    private let notificationService: NotificationService
    private let defaults: UserDefaults

    init(
        restClient: WPRestClient = WPRestClient(),
        notificationService: NotificationService,
        defaults: UserDefaults = .standard
    ) {
        self.restClient = restClient
        self.notificationService = notificationService
        self.defaults = defaults
    }

    /// Register the task handler. MUST be called synchronously from
    /// `application(_:didFinishLaunchingWithOptions:)` per the BGTaskScheduler
    /// contract.
    func register(on scheduler: BGTaskScheduler = .shared) {
        scheduler.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    /// Submit the next refresh request. Called when the scene backgrounds and at
    /// the end of every run — a `BGAppRefreshTask` fires once, so it must be
    /// re-armed or it never runs again.
    func scheduleNext(on scheduler: BGTaskScheduler = .shared) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.earliestInterval)
        do {
            try scheduler.submit(request)
        } catch {
            DODLog.app.notice("background-refresh submit failed: \(String(describing: error))")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        // BGAppRefreshTask is not Sendable, but its completion / expiration
        // methods are documented as callable from any thread, so cross it into
        // the completion Task through an unchecked box.
        let boxed = UncheckedBox(task)
        let poll = Task { await self.performNewPostCheck() }
        task.expirationHandler = { poll.cancel() }
        Task {
            await poll.value
            self.scheduleNext()
            boxed.value.setTaskCompleted(success: !poll.isCancelled)
        }
    }

    /// Fetch the newest post, decide, and — only when it is strictly newer —
    /// fire the gated notification. The baseline advances on every *successful*
    /// fetch (even when the notification gate suppresses the alert) so a later
    /// toggle-on never backlog-alerts; a fetch failure leaves it untouched.
    /// `internal` so a future integration test can drive it directly.
    func performNewPostCheck() async {
        guard let latest = try? await restClient.newestPost() else { return }
        let decision = NewPostPollDecision.decide(
            latestPostID: latest.id,
            lastSeenPostID: lastSeenPostID()
        )
        advanceLastSeen(to: latest.id)
        guard case .notify(let postID) = decision else { return }
        // RecipeListItem carries no recipe-vs-article kind in the background
        // window (kind is resolved by JSON-LD on detail fetch, AC-4.11/AC-37.2),
        // so default the banner copy to .recipe; the tap path re-classifies on
        // open. Known limitation: an article reads "New Recipe" in the banner.
        await notificationService.scheduleNewPostNotification(
            title: latest.title,
            postKind: .recipe,
            recipeID: postID
        )
    }

    private func lastSeenPostID() -> Int? {
        defaults.object(forKey: Self.lastSeenKey) as? Int
    }

    /// Persist only forward-moving ids (monotonic): a deleted top post can make
    /// the newest id go backwards; never lower the baseline.
    private func advanceLastSeen(to id: Int) {
        if let existing = lastSeenPostID(), id <= existing { return }
        defaults.set(id, forKey: Self.lastSeenKey)
    }
}

/// Crosses a non-Sendable value into a concurrency domain where the caller
/// guarantees thread-safe use — here a `BGAppRefreshTask`, whose completion
/// methods Apple documents as safe to call from any thread.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
