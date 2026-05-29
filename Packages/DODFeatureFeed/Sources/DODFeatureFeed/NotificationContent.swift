import DODDomain
import Foundation

/// Pure, `UNUserNotificationCenter`-free description of a single local
/// notification the app schedules when a new post is published
/// (spec US-41 / AC-41.2, AC-41.3).
///
/// Splitting the *content* (this type + ``NotificationContentBuilder``)
/// from the *scheduling* (the app-target `NotificationService` that wraps
/// `UNUserNotificationCenter`) keeps the type-aware copy + the deep-link
/// payload shape unit-testable from the `DODFeatureFeed` test target with
/// no `UserNotifications` dependency — the package's macOS `swift test`
/// slice never imports `UserNotifications`. The app target reads
/// ``title`` / ``body`` into a `UNMutableNotificationContent` and stamps
/// ``userInfo`` onto it verbatim.
///
/// Spec trace: US-41 / CL-86 (decisions 2 + 4).
public struct NotificationPlan: Equatable, Sendable {

    /// Notification title — the type-aware headline (AC-41.2):
    /// `"New Recipe 🍳"` for a recipe, `"New Article 📖"` for an article.
    public let title: String

    /// Notification body — the type-aware sentence interpolating the post
    /// title (AC-41.2).
    public let body: String

    /// `userInfo` payload copied onto the `UNMutableNotificationContent`.
    /// Carries the deep-link target under ``NotificationPlan/deepLinkKey``
    /// so the tap handler can route it through the existing
    /// `WidgetDeepLinkParser` / `DeepLinkDispatcher` path (AC-41.3).
    public let userInfo: [String: String]

    public init(title: String, body: String, userInfo: [String: String]) {
        self.title = title
        self.body = body
        self.userInfo = userInfo
    }

    /// Stable `userInfo` key under which the `dod://…` deep-link URL string
    /// travels. Read by the app target's
    /// `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)`.
    public static let deepLinkKey = "dod.deeplink"

    /// The deep-link URL string this plan carries, or `nil` if absent.
    /// Convenience for the tap-routing path + the L1 payload-shape test.
    public var deepLink: String? { userInfo[Self.deepLinkKey] }
}

/// Builds the type-aware ``NotificationPlan`` for a newly-published post.
///
/// The copy mapping is keyed purely on ``PostKind`` (US-37 / CL-63) — the
/// builder never inspects the post itself, so it is a pure function the
/// L1 suite pins per kind (AC-41.2) and the deep-link payload shape it
/// emits is asserted independently (AC-41.3 / AC-41.6).
///
/// Spec trace: US-41 / CL-86.
public enum NotificationContentBuilder {

    /// Build the notification plan for a post of the given ``PostKind``.
    ///
    /// - Parameters:
    ///   - postTitle: the post's display title, interpolated verbatim into
    ///     the body (AC-41.2). No truncation — the system handles overflow.
    ///   - postKind: `.recipe` or `.article` — drives the title + body copy
    ///     and the deep-link host (`recipe` vs. `article`).
    ///   - postID: the integer WP post id used to build the
    ///     `dod://<kind>/<id>` deep link stamped into ``NotificationPlan/userInfo``.
    public static func plan(
        postTitle: String,
        postKind: PostKind,
        postID: Int
    ) -> NotificationPlan {
        let title: String
        let body: String
        switch postKind {
        case .recipe:
            title = "New Recipe 🍳"
            body = "\(postTitle) just dropped — tap to start cooking."
        case .article:
            title = "New Article 📖"
            body = "\(postTitle) is up — tap to read."
        }
        // Reuse the existing `dod://` deep-link grammar (US-9 /
        // `WidgetDeepLinkParser`, US-10) — no new URL vocabulary. The host
        // mirrors the kind so the tap routes to the right surface.
        let host = postKind == .recipe ? "recipe" : "article"
        let deepLink = "dod://\(host)/\(postID)"
        return NotificationPlan(
            title: title,
            body: body,
            userInfo: [NotificationPlan.deepLinkKey: deepLink]
        )
    }

    /// The single suppression gate (AC-41.4 / CL-86 decision 3): a local
    /// notification may be scheduled **only** when the user's persisted
    /// intent (`dod.settings.notificationsEnabled`) is on **and** the OS
    /// has granted authorization. Off ⇒ silence, with no edge case that
    /// leaks a notification.
    ///
    /// Pure so the app-target scheduler delegates the decision here and the
    /// L1 suite pins the truth table without touching `UNUserNotificationCenter`.
    public static func shouldSchedule(toggleEnabled: Bool, systemAuthorized: Bool) -> Bool {
        toggleEnabled && systemAuthorized
    }
}
