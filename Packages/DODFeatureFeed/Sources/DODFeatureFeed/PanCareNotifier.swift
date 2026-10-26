import DODSupport
import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// DUT-971 — schedules / cancels the single "your pan misses you" reminder.
public protocol PanCareNotifying: Sendable {
    /// Replace any pending reminder with one `PanCare.idleDaysThreshold` days after `lastActivity`.
    func scheduleIdleReminder(lastActivity: Date, now: Date) async
    func cancelIdleReminder() async
}

public struct SystemPanCareNotifier: PanCareNotifying {
    static let identifier = "dod.panCare.idleReminder"
    static let title = "Your cast iron misses you"
    static let body = "It's been a few weeks. A quick wipe-and-oil keeps it ready to cook."

    public init() {}

    /// Seconds from `now` until the reminder fires; nil when already past (fire nothing).
    static func delay(lastActivity: Date, now: Date) -> TimeInterval? {
        let fire = lastActivity.addingTimeInterval(TimeInterval(PanCare.idleDaysThreshold) * 86_400)
        let delay = fire.timeIntervalSince(now)
        return delay > 0 ? delay : nil
    }

    public func scheduleIdleReminder(lastActivity: Date, now: Date) async {
        #if canImport(UserNotifications)
        guard UserDefaults.standard.bool(forKey: SettingsViewModel.notificationsEnabledKey),
            let delay = Self.delay(lastActivity: lastActivity, now: now)
        else { return }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        // Same identifier => replaces the previous pending request.
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
        #endif
    }

    public func cancelIdleReminder() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        #endif
    }
}
