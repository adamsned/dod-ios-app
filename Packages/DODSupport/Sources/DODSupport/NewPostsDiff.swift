import Foundation

/// Pure diff between the WP posts a poll just fetched and the highest post
/// id this install has already notified about (DUT-938 — the background
/// trigger for new-post notifications; see `NewPostsPoller` in the App
/// target for the impure fetch/notify/persist shell around this).
///
/// No `UserDefaults`, no networking, no `UserNotifications` — just the
/// decision of *which* ids are new and what the next persisted watermark
/// should be, so the tricky "first run vs. steady state" logic is
/// unit-testable without mocking anything.
public enum NewPostsDiff {

    /// Decides which post ids are new since the last poll, and the
    /// watermark to persist for the next one.
    ///
    /// - Parameters:
    ///   - latestPostIDs: WP post ids from the just-fetched page, newest or
    ///     oldest first — order doesn't matter, every id is considered.
    ///   - lastSeen: the highest post id this install has previously
    ///     recorded, or `nil` if it has never polled before.
    /// - Returns: `toNotify` — ids to schedule a notification for, sorted
    ///   DESCENDING (newest first) so a capped caller notifies the newest
    ///   posts first; `newLastSeen` — the watermark to persist next.
    ///
    /// Rules:
    /// 1. `latestPostIDs` empty → `([], lastSeen)`, unchanged.
    /// 2. `lastSeen == nil` (first poll ever) → `toNotify` is EMPTY (an
    ///    install must never be greeted with a backlog of notifications for
    ///    posts published before it existed) and `newLastSeen` becomes the
    ///    maximum of `latestPostIDs` — just a baseline.
    /// 3. Otherwise → `toNotify` is every DISTINCT id strictly greater than
    ///    `lastSeen`, sorted descending; `newLastSeen` is
    ///    `max(lastSeen, max(latestPostIDs))` (never regresses the
    ///    watermark even if a page returns only older ids).
    ///
    /// `latestPostIDs` is untrusted (a raw WP API response) and can repeat an
    /// id (the dup-id class this codebase has hit before, cf. `RecipeStore`
    /// #605 / `NewPostsPoller`'s `titlesByID` dictionary) — deduping before
    /// filtering keeps a repeated id from appearing twice in `toNotify`,
    /// which would otherwise make the caller schedule two separate local
    /// notifications for the same post.
    public static func resolve(
        latestPostIDs: [Int],
        lastSeen: Int?
    ) -> (toNotify: [Int], newLastSeen: Int?) {
        guard let highestFetched = latestPostIDs.max() else {
            return ([], lastSeen)
        }
        guard let lastSeen else {
            return ([], highestFetched)
        }
        let distinctDescending = Set(latestPostIDs).sorted(by: >)
        let toNotify = distinctDescending.filter { $0 > lastSeen }
        return (toNotify, max(lastSeen, highestFetched))
    }
}
