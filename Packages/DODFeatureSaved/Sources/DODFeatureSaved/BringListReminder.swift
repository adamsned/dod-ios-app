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
