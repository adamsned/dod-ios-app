import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("AnnouncementsViewModel (DUT-147)")
struct AnnouncementsViewModelTests {
    private nonisolated func makeDefaults() -> UserDefaults {
        let suiteName = "AnnouncementsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private nonisolated func item(_ id: Int) -> Announcement {
        Announcement(
            id: id,
            title: "Post \(id)",
            bodyMarkdown: "Body",
            publishedAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }

    @Test("loaded state sorts items newest-first")
    func loadedSortsNewestFirst() async {
        let vm = AnnouncementsViewModel(
            fetch: { [self.item(2), self.item(3), self.item(1)] },
            tracker: AnnouncementReadTracker(defaults: makeDefaults())
        )
        await vm.load()
        #expect(vm.state == .loaded)
        #expect(vm.items.map(\.id) == [3, 2, 1])
    }

    @Test("empty fetch gives the empty state")
    func emptyState() async {
        let vm = AnnouncementsViewModel(
            fetch: { [] },
            tracker: AnnouncementReadTracker(defaults: makeDefaults())
        )
        await vm.load()
        #expect(vm.state == .empty)
    }

    @Test("networkUnavailable gives the offline state")
    func offlineState() async {
        let vm = AnnouncementsViewModel(
            fetch: { throw WPClientError.networkUnavailable },
            tracker: AnnouncementReadTracker(defaults: makeDefaults())
        )
        await vm.load()
        #expect(vm.state == .offline)
    }

    @Test("markOpened takes unreadCount from 3 to 0 and logs the view event")
    func markOpenedClearsBadge() async {
        let recorder = EventRecorder()
        let vm = AnnouncementsViewModel(
            fetch: { [self.item(1), self.item(2), self.item(3)] },
            tracker: AnnouncementReadTracker(defaults: makeDefaults()),
            log: { recorder.record($0) }
        )
        await vm.load()
        #expect(vm.unreadCount == 3)
        vm.markOpened()
        #expect(vm.unreadCount == 0)
        #expect(recorder.events == ["announcement_feed_viewed"])
    }

    @Test("didTapDeepLink logs the tap event")
    func deepLinkTapLogs() {
        let recorder = EventRecorder()
        let vm = AnnouncementsViewModel(
            fetch: { [] },
            tracker: AnnouncementReadTracker(defaults: makeDefaults()),
            log: { recorder.record($0) }
        )
        vm.didTapDeepLink(item(1))
        #expect(recorder.events == ["announcement_deeplink_tapped"])
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var events: [String] { lock.withLock { storage } }
    func record(_ name: String) { lock.withLock { storage.append(name) } }
}
