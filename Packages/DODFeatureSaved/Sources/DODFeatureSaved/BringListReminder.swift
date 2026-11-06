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
public struct SystemBringListReminder {
    static let identifier = "dod.bringList.packTheTruck"
    static let title = "Pack the truck"
    static let body = "Check your Bring List - tongs, chimney, coals and Dutch ovens."
    private let isEnabled: @Sendable () -> Bool

    public init(isEnabled: @escaping @Sendable () -> Bool) {
        self.isEnabled = isEnabled
    }
}
