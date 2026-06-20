import Foundation

/// The pure decision at the heart of the DUT-15 / T-787 background new-post
/// poll: given the newest post id the feed reports and the last id we acted on,
/// decide whether to fire a new-post notification.
///
/// Kept free of `BackgroundTasks`, `UserNotifications`, and any I/O so it runs
/// under `swift test` on macOS exactly like `NotificationContentBuilder`. The
/// orchestrator (`BackgroundRefreshService` in the app target) does the fetch,
/// the `UserDefaults` baseline read/write, and the gated notification call
/// around this decision.
///
/// Rules (NFR-3 amended / CL-183):
/// - **First run** (`lastSeenPostID == nil`): `.skip`. The caller records the
///   current newest id as a baseline; we never alert for a pre-existing post
///   the moment the user enables notifications.
/// - **Newer** (`latest` strictly greater than last seen): `.notify(latest)`.
/// - **Same or backwards** (`latest <= lastSeen`, e.g. an edited post keeping
///   its id, or a deleted top post lowering the newest id): `.skip`. Strict
///   `>` is the dedup + monotonic guard.
public enum NewPostPollDecision: Equatable, Sendable {

    case notify(postID: Int)
    case skip

    public static func decide(latestPostID: Int, lastSeenPostID: Int?) -> NewPostPollDecision {
        guard let lastSeen = lastSeenPostID else { return .skip }
        return latestPostID > lastSeen ? .notify(postID: latestPostID) : .skip
    }
}
