import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// DUT-297 — schedules / cancels the "your bake is done" local notification
/// behind the guided First Cookout bake timer. The cook stage explicitly tells
/// the beginner "you can step away", but the countdown was progressed only by a
/// foreground tick loop, so a backgrounded bake never finished and never
/// alerted. Scheduling a `UNUserNotificationCenter` notification at the deadline
/// keeps that promise — and lets the first-run notification permission prompt
/// (DUT-278) actually pay off.
///
/// DUT-547 — the guided path shares ONE `CookTimerEngine` across every rung
/// (DUT-484), so two rungs' bakes can be pending at once. Notifications are now
/// keyed per recipe (``identifier(for:)``) so starting rung B's bake no longer
/// replaces rung A's still-pending alert, and finishing/cancelling one rung's
/// timer only removes THAT rung's request — never a sibling's.
///
/// A protocol seam so `FirstCookoutView` stays previewable / testable without
/// `UNUserNotificationCenter`.
public protocol BakeTimerNotifying: Sendable {
    /// Schedule the bake-done notification `seconds` from now for `recipeID`. A
    /// non-positive duration is a no-op (nothing to wait on). `recipeID` keys
    /// the request so concurrent guided bakes don't clobber each other
    /// (DUT-547); `nil` uses the shared fallback id (the single-timer
    /// non-guided / dump-cake path).
    func scheduleBakeDone(after seconds: TimeInterval, recipeID: Int?) async
    /// Cancel the pending (and any already-delivered) bake-done notification for
    /// `recipeID` — the user cancelled that timer, or it finished in the
    /// foreground. Only that recipe's request is removed (DUT-547).
    func cancelBakeDone(for recipeID: Int?) async
    /// Cancel EVERY pending / delivered bake-done notification, across all
    /// recipes — the "off ⇒ silence" opt-out flush (DUT-379), where we don't
    /// know (or care) which rungs have bakes queued.
    func cancelAllBakeDone() async
}

/// `UNUserNotificationCenter`-backed implementation. Best-effort: if the user
/// hasn't granted notification permission the request silently no-ops, exactly
/// like the rest of the app's notification surfaces.
public struct SystemBakeTimerNotifier: BakeTimerNotifying {

    /// Base of the per-recipe notification identifier. DUT-547 — a re-scheduled
    /// or cancelled timer replaces / removes only its OWN recipe's request
    /// rather than stacking duplicates or clobbering a sibling rung's alert.
    static let identifier = "dod.firstCookout.bakeDone"
    static let title = "Your bake is done!"
    static let body = "Time to check your Dutch oven — carefully lift the lid and see how it turned out."

    /// DUT-443 — schedule the alert this far AFTER the engine deadline. The
    /// foreground finish is detected on the NEXT 1 Hz tick (~0.5s average) and
    /// `cancelBakeDone` only removes PENDING requests — with the alert at the
    /// exact deadline it was already delivered by cancel time, so an on-screen
    /// finish showed the in-app "Timer's up!" card AND the system banner. The
    /// grace lets the foreground cancel win; a backgrounded bake alert lands a
    /// negligible 2s late.
    static let deliveryGrace: TimeInterval = 2

    public init() {}

    /// DUT-547 — per-recipe identifier so two guided rungs' bakes can be pending
    /// simultaneously without one replacing the other. A `nil` recipeID (the
    /// single-timer non-guided / dump-cake path, or an unscoped timer) falls
    /// back to the base id — a no-op change there since only one is ever pending.
    static func identifier(for recipeID: Int?) -> String {
        guard let recipeID else { return identifier }
        return "\(identifier).\(recipeID)"
    }

    public func scheduleBakeDone(after seconds: TimeInterval, recipeID: Int?) async {
        #if canImport(UserNotifications)
        guard seconds > 0 else { return }
        // DUT-379: respect the app's notification toggle — don't schedule a bake
        // alert the user opted out of ("off ⇒ silence"). Mirrors the post-alert
        // gate in `NotificationService.scheduleNewPostNotification`. (A bake-done
        // already scheduled before the user opted out is cancelled by the
        // Settings toggle's opt-out path.)
        guard UserDefaults.standard.bool(forKey: SettingsViewModel.notificationsEnabledKey) else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds + Self.deliveryGrace,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: recipeID),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    public func cancelBakeDone(for recipeID: Int?) async {
        #if canImport(UserNotifications)
        let ids = [Self.identifier(for: recipeID)]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        #endif
    }

    public func cancelAllBakeDone() async {
        #if canImport(UserNotifications)
        // DUT-379 opt-out flush: we can't enumerate which per-recipe ids are
        // queued, so drop every pending / delivered bake-done request whose id
        // is (or is prefixed by) the base identifier.
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending.map(\.identifier).filter(Self.isBakeDoneIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map(\.request.identifier).filter(Self.isBakeDoneIdentifier)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        #endif
    }

    /// Whether `id` is a bake-done request — the bare base id (nil-recipe
    /// fallback) or any `base.<recipeID>` per-recipe id.
    static func isBakeDoneIdentifier(_ id: String) -> Bool {
        id == identifier || id.hasPrefix("\(identifier).")
    }
}
