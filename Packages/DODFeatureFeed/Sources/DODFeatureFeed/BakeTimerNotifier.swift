import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// DUT-297 — schedules / cancels the single "your bake is done" local
/// notification behind the guided First Cookout bake timer. The cook stage
/// explicitly tells the beginner "you can step away", but the countdown was
/// progressed only by a foreground tick loop, so a backgrounded bake never
/// finished and never alerted. Scheduling a `UNUserNotificationCenter`
/// notification at the deadline keeps that promise — and lets the first-run
/// notification permission prompt (DUT-278) actually pay off.
///
/// A protocol seam so `FirstCookoutView` stays previewable / testable without
/// `UNUserNotificationCenter`.
public protocol BakeTimerNotifying: Sendable {
    /// Schedule the bake-done notification `seconds` from now. A non-positive
    /// duration is a no-op (nothing to wait on).
    func scheduleBakeDone(after seconds: TimeInterval) async
    /// Cancel the pending bake-done notification (the user cancelled the timer,
    /// or it finished while the app was in the foreground — no need to alert).
    func cancelBakeDone() async
}

/// `UNUserNotificationCenter`-backed implementation. Best-effort: if the user
/// hasn't granted notification permission the request silently no-ops, exactly
/// like the rest of the app's notification surfaces.
public struct SystemBakeTimerNotifier: BakeTimerNotifying {

    /// Stable identifier so a re-scheduled or cancelled timer replaces / removes
    /// the prior request rather than stacking duplicate alerts.
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

    public func scheduleBakeDone(after seconds: TimeInterval) async {
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
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    public func cancelBakeDone() async {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        #endif
    }
}
