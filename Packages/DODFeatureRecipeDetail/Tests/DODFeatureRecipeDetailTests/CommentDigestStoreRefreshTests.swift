import DODDomain
import DODFeatureRecipeDetail
import DODIntelligence
import Foundation
import Testing

@MainActor
struct CommentDigestStoreRefreshTests {
    @Test
    func loadsCannedDigestWithFake() async {
        let store = CommentDigestStore(intelligence: FakeIntelligenceService())

        await store.refresh(comments: CommentDigestFixtures.approved(3))

        #expect(store.state == .loaded(.canned))
    }

    @Test
    func belowMinimumIsUnavailable() async {
        let store = CommentDigestStore(intelligence: FakeIntelligenceService())

        await store.refresh(comments: CommentDigestFixtures.approved(2))

        #expect(store.state == .unavailable)
    }

    @Test
    func unavailableServiceIsUnavailable() async {
        let store = CommentDigestStore(intelligence: FakeIntelligenceService(isAvailable: false))

        await store.refresh(comments: CommentDigestFixtures.approved(3))

        #expect(store.state == .unavailable)
    }

    @Test
    func nilServiceIsUnavailable() async {
        let store = CommentDigestStore(intelligence: nil)

        await store.refresh(comments: CommentDigestFixtures.approved(3))

        #expect(store.state == .unavailable)
    }
}
