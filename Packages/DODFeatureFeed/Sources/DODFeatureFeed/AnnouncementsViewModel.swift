import DODDomain
import Foundation
import Observation

/// State + loading logic for the "From Ned" announcements feed (DUT-147).
@MainActor @Observable
public final class AnnouncementsViewModel {
    public enum State: Equatable { case idle, loading, loaded, empty, offline }

    public private(set) var state: State = .idle
    public private(set) var items: [Announcement] = []

    private let fetch: @Sendable () async throws -> [Announcement]
    private let tracker: AnnouncementReadTracker
    /// Event name; wired to DODAnalytics by the app (no DODAnalytics dependency here).
    private let log: @Sendable (String) -> Void

    public init(
        fetch: @escaping @Sendable () async throws -> [Announcement],
        tracker: AnnouncementReadTracker = .init(),
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.fetch = fetch
        self.tracker = tracker
        self.log = log
    }

    public var unreadCount: Int { tracker.unreadCount(in: items) }

    /// Call when the feed screen appears: clears the badge and logs the impression.
    public func markOpened() {
        tracker.markAllRead(items)
        log("announcement_feed_viewed")
    }

    public func didTapDeepLink(_ announcement: Announcement) {
        log("announcement_deeplink_tapped")
    }

    public func load() async {
        state = .loading
        do {
            let result = try await fetch()
            items = result.sorted { $0.publishedAt > $1.publishedAt }
            state = items.isEmpty ? .empty : .loaded
        } catch {
            // Keep any previously loaded items visible; only show offline when we have nothing.
            state = items.isEmpty ? .offline : .loaded
        }
    }
}
