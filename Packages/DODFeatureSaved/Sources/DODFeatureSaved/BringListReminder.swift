import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// DUT-1998 - schedules / cancels the "pack the truck" local reminder
/// for the Bring List. A protocol seam so views stay testable without
/// `UNUserNotificationCenter`.
public protocol BringListReminding: Sendable {
    func schedulePackReminder(at date: Date) async
    func cancelPackReminder() async
}

/// `UNUserNotificationCenter`-backed implementation. The notifications
/// toggle is injected as a closure so this package need not import the
/// Settings module.
public struct SystemBringListReminder: BringListReminding {
    static let identifier = "dod.bringList.packTheTruck"
    static let title = "Pack the truck"
    static let body = "Check your Bring List - tongs, chimney, coals and Dutch ovens."
    private let isEnabled: @Sendable () -> Bool

    public init(isEnabled: @escaping @Sendable () -> Bool) {
        self.isEnabled = isEnabled
    }
}

extension SystemBringListReminder {
    /// Seconds until `date`, or nil if it is not in the future.
    static func interval(until date: Date, now: Date = Date()) -> TimeInterval? {
        let seconds = date.timeIntervalSince(now)
        return seconds > 0 ? seconds : nil
    }

    public func schedulePackReminder(at date: Date) async {
        #if canImport(UserNotifications)
        guard isEnabled(), let seconds = Self.interval(until: date) else { return }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
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

    public func cancelPackReminder() async {
        #if canImport(UserNotifications)
        let ids = [Self.identifier]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        #endif
    }
}
