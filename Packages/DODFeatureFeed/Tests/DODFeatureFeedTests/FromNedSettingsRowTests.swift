import DODDomain
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed

@Suite("From Ned settings row (DUT-1617)") struct FromNedSettingsRowTests {
    @Test func unreadCountCountsOnlyNewerThanLastRead() {
        let suiteName = "FromNedSettingsRowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let tracker = AnnouncementReadTracker(defaults: defaults)
        func item(_ id: Int) -> Announcement {
            Announcement(id: id, title: "t", bodyMarkdown: "b", publishedAt: Date())
        }
        #expect(SettingsView.fromNedUnreadCount(in: [item(1), item(2)], tracker: tracker) == 2)
        tracker.markAllRead([item(1)])
        #expect(SettingsView.fromNedUnreadCount(in: [item(1), item(2)], tracker: tracker) == 1)
    }

    @Test func placeholderCategoryIDIsZero() {
        #expect(SettingsView.announcementsCategoryID == 0)
    }

    @Test @MainActor func fromNedLinkBuilds() {
        _ = FromNedSettingsLink(unreadCount: 3).body
        _ = FromNedSettingsLink(unreadCount: 0).body
    }

    @Test @MainActor func settingsViewBuildsWithFromNedRow() {
        let view = NavigationStack { SettingsView() }
        _ = view
        #expect(SettingsView().fromNedUnreadCount == 0)
    }
}
