import DODCookActivity
import Foundation

#if os(iOS)
import ActivityKit
#endif

/// Lets ``CookModeViewModel`` drive ActivityKit in production while letting
/// tests stub the start/update/end side-effects with a plain in-memory class.
///
/// Spec trace: US-11 (Live Activity for Cook Mode timers). The protocol
/// stays platform-neutral so the view model — which still builds on macOS
/// for `swift test` — can hold a reference without importing ActivityKit.
/// The production conformance lives in ``SystemCookLiveActivityController``
/// and is the only place that touches the real `Activity` API.
@MainActor
public protocol CookLiveActivityController: AnyObject {
    /// True when an activity is currently being driven by this controller.
    /// Plumbed through to ``CookModeViewModel/hasLiveActivity`` so tests can
    /// assert the start/stop toggle without inspecting ActivityKit itself.
    var isActive: Bool { get }

    /// DUT-558: whether ActivityKit will accept a `start` at all right now —
    /// mirrors `ActivityAuthorizationInfo().areActivitiesEnabled`. False means
    /// Live Activities are disabled in Settings or over quota, so a failed
    /// `start` is PERMANENT (not transient) and the view model must stop
    /// re-attempting it every tick. Rechecked on scene-activate.
    var areActivitiesEnabled: Bool { get }

    /// Begin a new Live Activity for the supplied recipe + step text +
    /// duration. Idempotent: if one is already running, end it and start
    /// fresh so the user sees the new step's countdown.
    func start(
        attributes: CookActivityAttributes,
        initialState: CookActivityAttributes.ContentState
    )

    /// Push a new content state — usually called once per second from the
    /// view model's timer tick.
    func update(state: CookActivityAttributes.ContentState)

    /// Tear down the activity. Safe to call when nothing is running.
    func end()
}

/// Production conformance — backed by `ActivityKit.Activity`.
///
/// On macOS hosts (or any platform without ActivityKit) the type still
/// compiles and satisfies the protocol but the start/update/end calls are
/// no-ops. This keeps `swift test` green on the package's macOS slice.
@MainActor
public final class SystemCookLiveActivityController: CookLiveActivityController {

    public init() {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            reconcileOrphans()
        }
        #endif
    }

    #if os(iOS)
    deinit {
        // DUT-474: if this controller is torn down while still holding an
        // activity (e.g. the hosting scene is destroyed in iPad App Exposé, which
        // doesn't reliably deliver `onDisappear` → `endCookMode`), drop its id
        // from the live registry WITHOUT ending it. The card lingers, but the
        // next controller construction now sees it as an orphan (its id is no
        // longer registered by any live controller) and reconciles it away —
        // whereas the old once-per-process flag could never end an in-process
        // orphan. `deinit` is nonisolated; the registry is lock-guarded.
        if #available(iOS 16.1, *), let id = registeredActivityID {
            CookLiveActivityOrphanRegistry.shared.unregister(id)
        }
    }

    @available(iOS 16.1, *)
    private var activity: Activity<CookActivityAttributes>? {
        // Erased through Any storage so we don't have to leak the iOS-only
        // availability annotation to every property accessor.
        get { activityStorage as? Activity<CookActivityAttributes> }
        set { activityStorage = newValue }
    }

    private var activityStorage: Any?

    /// DUT-474: the id of the activity this controller is currently driving, kept
    /// out of the availability-gated `activity` computed property so `deinit`
    /// (nonisolated, and it can't touch `@available` stored state through the
    /// computed accessor) can unregister it. Mirrors `activity?.id`.
    private var registeredActivityID: String?
    #endif

    public var isActive: Bool {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            return activity != nil
        }
        return false
        #else
        return false
        #endif
    }

    public var areActivitiesEnabled: Bool {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
        #else
        return false
        #endif
    }

    public func start(
        attributes: CookActivityAttributes,
        initialState: CookActivityAttributes.ContentState
    ) {
        #if os(iOS)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Replace any in-flight activity so a new timer doesn't accumulate
        // multiple stacked Lock-Screen cards.
        endExistingActivity()
        let content = ActivityContent(state: initialState, staleDate: staleDate(for: initialState))
        do {
            let started = try Activity<CookActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activity = started
            // DUT-474: register the live id so the next controller's reconcile
            // treats it as owned (not an orphan) while this controller lives.
            registeredActivityID = started.id
            CookLiveActivityOrphanRegistry.shared.register(started.id)
        } catch {
            // Most failures here are quota / authorization related. Log path
            // would go through DODSupport.Logger in a follow-up; for now we
            // swallow so a failed Live Activity never breaks Cook Mode.
            activity = nil
        }
        #endif
    }

    public func update(state: CookActivityAttributes.ContentState) {
        #if os(iOS)
        guard #available(iOS 16.1, *), let activity else { return }
        let content = ActivityContent(state: state, staleDate: staleDate(for: state))
        Self.pushUpdate(activity: activity, content: content)
        #endif
    }

    public func end() {
        #if os(iOS)
        guard #available(iOS 16.1, *) else { return }
        endExistingActivity()
        #endif
    }

    #if os(iOS)
    /// DUT-309 / DUT-474 — ActivityKit Live Activities outlive both app
    /// termination AND scene teardown: a card requested before a process kill (or
    /// held by a controller whose scene was destroyed) persists on the Lock
    /// Screen / Dynamic Island with no live in-memory handle able to update or
    /// end it. Runs on EVERY construction: end any activity whose id is not held
    /// by a currently-live controller (the ``CookLiveActivityOrphanRegistry``), so
    /// both a cross-process orphan (DUT-309) and an in-process scene orphan
    /// (DUT-474) are cleaned up. The registry membership check means the installed
    /// controller's own card is spared (DUT-431 no-kill guarantee).
    @available(iOS 16.1, *)
    private func reconcileOrphans() {
        let existing = Activity<CookActivityAttributes>.activities
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for orphanID in CookLiveActivityOrphanRegistry.shared.orphanIDs(amongExisting: existing.map(\.id)) {
            if let orphan = byID[orphanID] { Self.pushEndOrphan(orphan) }
        }
    }

    @available(iOS 16.1, *)
    nonisolated private static func pushEndOrphan(
        _ activity: Activity<CookActivityAttributes>
    ) {
        let box = UncheckedSendableActivity(activity)
        Task { await box.activity.end(nil, dismissalPolicy: .immediate) }
    }

    @available(iOS 16.1, *)
    private func endExistingActivity() {
        guard let activity else { return }
        self.activity = nil
        // DUT-474: this controller no longer owns the id — drop it from the
        // registry so a later reconcile doesn't treat the (ending) activity as
        // still-owned.
        if let id = registeredActivityID {
            CookLiveActivityOrphanRegistry.shared.unregister(id)
            registeredActivityID = nil
        }
        let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
        Self.pushEnd(activity: activity, content: finalContent)
    }

    /// Hop the awaitable `Activity.update` into a nonisolated context so
    /// strict-concurrency doesn't trip on sending a MainActor-owned
    /// `Activity` handle across actor boundaries. `Activity` itself is
    /// thread-safe per Apple's ActivityKit documentation but isn't
    /// formally Sendable in the SDK, so we wrap it in
    /// ``UncheckedSendableActivity`` for the hand-off.
    @available(iOS 16.1, *)
    nonisolated private static func pushUpdate(
        activity: Activity<CookActivityAttributes>,
        content: ActivityContent<CookActivityAttributes.ContentState>
    ) {
        let box = UncheckedSendableActivity(activity)
        Task { await box.activity.update(content) }
    }

    @available(iOS 16.1, *)
    nonisolated private static func pushEnd(
        activity: Activity<CookActivityAttributes>,
        content: ActivityContent<CookActivityAttributes.ContentState>
    ) {
        let box = UncheckedSendableActivity(activity)
        Task { await box.activity.end(content, dismissalPolicy: .immediate) }
    }

    /// `Activity` is documented as thread-safe but isn't formally
    /// `Sendable`. The wrapper lets us hand off a reference across
    /// actor boundaries under Swift 6 strict concurrency without
    /// quieting unrelated diagnostics with a global `@unchecked` on
    /// the controller itself.
    @available(iOS 16.1, *)
    private struct UncheckedSendableActivity: @unchecked Sendable {
        let activity: Activity<CookActivityAttributes>
        init(_ activity: Activity<CookActivityAttributes>) { self.activity = activity }
    }

    @available(iOS 16.1, *)
    private func staleDate(for state: CookActivityAttributes.ContentState) -> Date {
        // DUT-490: the DUT-354 completed-linger is pushed exactly once (per-tick
        // re-pushes are suppressed while it lingers), so its stale date is never
        // refreshed — a `now + 15s` stamp would dim the card after ~15s. Give the
        // single "done" push a far-future stale date so it stays full-brightness
        // until the cook leaves Cook Mode (which ends it).
        if state.isCompleted { return .distantFuture }
        // Mark a running/paused activity stale a couple of ticks after the
        // countdown is expected to hit zero. iOS keeps the card on the Lock
        // Screen briefly after it's considered stale; the slack keeps the buzzer
        // moment from being preempted.
        return Date().addingTimeInterval(TimeInterval(max(state.remainingSeconds, 0) + 15))
    }
    #endif
}
