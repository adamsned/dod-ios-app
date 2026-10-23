#if canImport(UIKit)
import DODDomain
import Foundation
import SwiftUI
import Testing
import UIKit

@testable import DODFeatureFeed

@MainActor
@Suite("AnnouncementsView (DUT-1616)") struct AnnouncementsViewTests {
    private func makeDefaults() -> UserDefaults {
        let name = "AnnouncementsViewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func host(
        fetch: @escaping @Sendable () async throws -> [Announcement]
    ) async -> UIHostingController<AnnouncementsView> {
        let vm = AnnouncementsViewModel(fetch: fetch, tracker: AnnouncementReadTracker(defaults: makeDefaults()))
        await vm.load()
        let host = UIHostingController(rootView: AnnouncementsView(viewModel: vm, onOpenDeepLink: { _ in }))
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        return host
    }

    @Test func rendersEmptyState() async {
        let hosted = await host(fetch: { [] })
        #expect(hosted.view != nil)
    }

    @Test func rendersOfflineState() async {
        struct Boom: Error {}
        let hosted = await host(fetch: { throw Boom() })
        #expect(hosted.view != nil)
    }
}
#endif
