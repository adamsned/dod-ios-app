import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// DUT-604 — schedules / cancels the "your step timer is done" local
/// notification behind a Cook Mode step timer. Cook Mode explicitly lets the
/// cook step away (the Live Activity / Lock Screen countdown is built for it),
/// but the in-app "buzzer" only fired on the foreground 1 Hz tick loop
/// (`tickTimers`), so a backgrounded step timer counted down on the Lock Screen
/// yet never alerted when it hit zero. This mirrors ``SystemBakeTimerNotifier``
/// (the guided First Cookout bake path, DUT-297) for the Cook Mode step-timer
/// case: a `UNTimeIntervalNotificationTrigger` fires at the deadline so a
/// backgrounded step still alerts.
///
/// Keyed per (recipe, step) so several concurrently-running step timers each
/// own their own request — starting step 3's timer never replaces step 1's
/// still-pending alert, and pausing / resetting / finishing one step's timer
/// only removes THAT step's request.
///
/// A protocol seam so ``CookModeViewModel`` stays previewable / testable
/// without `UNUserNotificationCenter`.
@MainActor
public protocol CookStepTimerNotifying: Sendable {
    /// Schedule the step-done notification `seconds` from now for
    /// `(recipeID, stepIndex)`. A non-positive duration is a no-op.
    func scheduleStepDone(after seconds: TimeInterval, recipeID: Int, stepIndex: Int) async
    /// Cancel the pending (and any already-delivered) step-done notification for
    /// `(recipeID, stepIndex)` — the user paused / reset that timer, or it
    /// finished in the foreground. Only that step's request is removed.
    func cancelStepDone(recipeID: Int, stepIndex: Int) async
    /// Cancel EVERY pending / delivered step-done notification for `recipeID` —
    /// the Cook Mode session ended, so no step alert should survive it.
    func cancelAllStepDone(recipeID: Int) async
}

/// `UNUserNotificationCenter`-backed implementation. Best-effort: if the user
/// hasn't granted notification permission the request silently no-ops, exactly
/// like the rest of the app's notification surfaces.
public struct SystemCookStepTimerNotifier: CookStepTimerNotifying {

    /// Base of the per-(recipe, step) notification identifier.
    static let identifier = "dod.cookMode.stepTimerDone"
    static let title = "Your timer's up!"
    static let body = "Head back to your recipe — this step's timer just finished."

    /// The app-wide notifications opt-out key. Duplicated as a string literal
    /// (not referenced from `DODFeatureFeed.SettingsViewModel`) because
    /// `DODFeatureRecipeDetail` deliberately does not depend on the Feed feature
    /// module; the key value is a stable persisted contract. Mirrors the
    /// `SystemBakeTimerNotifier` opt-out gate ("off ⇒ silence").
    static let notificationsEnabledKey = "dod.settings.notificationsEnabled"

    /// Schedule the alert this far AFTER the deadline so a foreground finish —
    /// detected on the next 1 Hz `tickTimers`, which then cancels the pending
    /// request — wins the race and the cook doesn't get both the in-app buzzer
    /// AND a redundant system banner. Mirrors `SystemBakeTimerNotifier`.
    static let deliveryGrace: TimeInterval = 2

    public init() {}

    /// Per-(recipe, step) identifier so several running step timers can each be
    /// pending at once without one replacing another.
    static func identifier(recipeID: Int, stepIndex: Int) -> String {
        "\(identifier).\(recipeID).\(stepIndex)"
    }

    /// Whether it's safe to touch `UNUserNotificationCenter.current()`. Under
    /// `swift test` the process has no app bundle (the main bundle is the
    /// toolchain), and `currentNotificationCenter` throws
    /// `bundleProxyForCurrentProcess is nil`. Guarding on a real bundle id keeps
    /// the DEFAULT-injected notifier a safe no-op in unit tests (the CookMode VM
    /// suites run against the real notifier), exactly as the app's real
    /// notification surfaces degrade without permission.
    static var hasHostBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    public func scheduleStepDone(after seconds: TimeInterval, recipeID: Int, stepIndex: Int) async {
        #if canImport(UserNotifications)
        guard seconds > 0, Self.hasHostBundle else { return }
        // Respect the app's notification toggle — don't schedule an alert the
        // user opted out of. Mirrors `SystemBakeTimerNotifier`.
        guard UserDefaults.standard.bool(forKey: Self.notificationsEnabledKey) else { return }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds + Self.deliveryGrace,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier(recipeID: recipeID, stepIndex: stepIndex),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    public func cancelStepDone(recipeID: Int, stepIndex: Int) async {
        #if canImport(UserNotifications)
        guard Self.hasHostBundle else { return }
        let ids = [Self.identifier(recipeID: recipeID, stepIndex: stepIndex)]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        #endif
    }

    public func cancelAllStepDone(recipeID: Int) async {
        #if canImport(UserNotifications)
        guard Self.hasHostBundle else { return }
        // We can't enumerate which per-step ids are queued, so drop every
        // pending / delivered step-done request for this recipe.
        let prefix = "\(Self.identifier).\(recipeID)."
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        #endif
    }
}
