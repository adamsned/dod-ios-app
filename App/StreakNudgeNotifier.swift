import DODFeatureFeed
import DODSupport
import Foundation
import UserNotifications

/// DUT-972 — schedules the gentle weeknight streak-keeper local notification.
/// Gated by the Settings toggle, OS authorization and the 5-day cap in
/// ``StreakNudge``. Follows the per-feature notifier pattern of
/// `CookStepTimerNotifier`.
@MainActor
final class StreakNudgeNotifier {
    nonisolated static let identifier = "dod.streakNudge"
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    /// Pure builder, unit-tested. Deep link reuses `NotificationPlan.deepLinkKey`.
    nonisolated static func makeRequest(
        content: StreakNudge.Content,
        fireIn seconds: TimeInterval
    ) -> UNNotificationRequest {
        let mutable = UNMutableNotificationContent()
        mutable.title = content.title
        mutable.body = content.body
        mutable.sound = .default
        mutable.userInfo = [NotificationPlan.deepLinkKey: StreakNudge.deepLink]
        return UNNotificationRequest(
            identifier: identifier,
            content: mutable,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        )
    }

    /// Returns true if a nudge was scheduled.
    @discardableResult
    func evaluateAndSchedule(
        entries: [CookLogEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> Bool {
        guard defaults.bool(forKey: SettingsViewModel.streakNudgesEnabledKey) else { return false }
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return false
        }
        let status = StreakNudge.status(entries, asOf: now, calendar: calendar)
        let lastSent = defaults.object(forKey: SettingsViewModel.streakNudgeLastSentKey) as? Date
        guard let content = StreakNudge.content(for: status),
            StreakNudge.shouldSend(lastSent: lastSent, now: now)
        else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        do {
            try await center.add(Self.makeRequest(content: content, fireIn: 60))
        } catch {
            return false
        }
        defaults.set(now, forKey: SettingsViewModel.streakNudgeLastSentKey)
        return true
    }
}
