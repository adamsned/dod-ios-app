import DODDomain
import DODFeatureFeed
import DODSupport
import Foundation
import UserNotifications

/// On-device *local* notification service (spec US-42 / CL-100).
///
/// Wraps `UNUserNotificationCenter` for the two things the app needs:
/// requesting authorization when the Settings toggle is flipped ON
/// (AC-42.1) and scheduling a type-aware local notification for a newly
/// published post (AC-42.2 / AC-42.3). There is **no** Apple Push / APNs
/// in v1 — no device token, no remote payload, no server (CL-100 decision
/// 1). The single suppression gate (AC-42.4) lives in
/// ``scheduleNewPostNotification(title:postKind:recipeID:)``: it schedules
/// nothing unless the persisted toggle is ON **and** the OS has granted
/// authorization, delegating that truth-table decision to the pure
/// `NotificationContentBuilder.shouldSchedule(...)` so the gate is
/// unit-tested in `DODFeatureFeed` without a `UserNotifications` dependency.
///
/// `@MainActor` because it is constructed in the composition root and its
/// authorization closure is handed to `SettingsViewModel` (also MainActor).
@MainActor
final class NotificationService {

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    /// Requests `[.alert, .sound]` authorization (AC-42.1). Returns `true`
    /// iff the user grants. No `.badge` — v1 has no badge-count source
    /// (CL-100 decision 1). Errors are logged + treated as "not granted" so
    /// the toggle reverts rather than claiming notifications are on.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            DODLog.app.error("notification authorization failed: \(String(describing: error))")
            return false
        }
    }

    /// Live OS authorization status — `true` for `.authorized`,
    /// `.provisional`, or `.ephemeral`. Half of the suppression gate
    /// (AC-42.4); the other half is the persisted toggle.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// Schedules a single type-aware local notification for a newly
    /// published post (AC-42.2 / AC-42.3), **gated** by the toggle + OS
    /// authorization (AC-42.4). When notifications are OFF or permission is
    /// not granted this schedules nothing and returns — the single choke
    /// point so "off ⇒ silence" is an invariant, not a per-call-site
    /// convention.
    ///
    /// - Parameters:
    ///   - title: the post's display title (interpolated into the body).
    ///   - postKind: drives the title/body copy + the deep-link host.
    ///   - recipeID: the WP post id baked into the `dod://<kind>/<id>`
    ///     deep link stamped into `userInfo` for the tap handler.
    func scheduleNewPostNotification(title: String, postKind: PostKind, recipeID: Int) async {
        let toggleEnabled = defaults.bool(forKey: SettingsViewModel.notificationsEnabledKey)
        let authorized = await isAuthorized()
        guard
            NotificationContentBuilder.shouldSchedule(
                toggleEnabled: toggleEnabled,
                systemAuthorized: authorized
            )
        else {
            return
        }

        let plan = NotificationContentBuilder.plan(
            postTitle: title,
            postKind: postKind,
            postID: recipeID
        )
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.userInfo = plan.userInfo

        // ~1–2s immediate trigger — there is no real publish event in v1,
        // so the notification fires shortly after it is scheduled.
        // `repeats: false` — one-shot.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            DODLog.app.error("notification schedule failed: \(String(describing: error))")
        }
    }
}
