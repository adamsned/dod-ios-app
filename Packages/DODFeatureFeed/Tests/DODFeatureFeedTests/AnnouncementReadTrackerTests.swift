import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("AnnouncementReadTracker (DUT-147)")
struct AnnouncementReadTrackerTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "AnnouncementReadTrackerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func item(_ id: Int) -> Announcement {
        Announcement(
            id: id,
            title: "Post \(id)",
            bodyMarkdown: "Body",
            publishedAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }

    @Test("fresh state counts every item as unread")
    func freshStateAllUnread() {
        let tracker = AnnouncementReadTracker(defaults: makeDefaults())
        #expect(tracker.lastReadID == 0)
        #expect(tracker.unreadCount(in: [item(1), item(2), item(3)]) == 3)
    }

    @Test("markAllRead clears the unread count and stores the max id")
    func markAllReadClears() {
        let tracker = AnnouncementReadTracker(defaults: makeDefaults())
        let items = [item(1), item(2), item(3)]
        tracker.markAllRead(items)
        #expect(tracker.unreadCount(in: items) == 0)
        #expect(tracker.lastReadID == 3)
    }

    @Test("a newer item after markAllRead is the only unread one")
    func newerItemIsUnread() {
        let tracker = AnnouncementReadTracker(defaults: makeDefaults())
        tracker.markAllRead([item(1), item(2), item(3)])
        #expect(tracker.unreadCount(in: [item(1), item(2), item(3), item(4)]) == 1)
    }

    @Test("markAllRead with an empty list leaves lastReadID unchanged")
    func emptyMarkIsNoOp() {
        let tracker = AnnouncementReadTracker(defaults: makeDefaults())
        tracker.markAllRead([item(1), item(2), item(3)])
        tracker.markAllRead([])
        #expect(tracker.lastReadID == 3)
    }
}
