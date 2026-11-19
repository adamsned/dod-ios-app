import DODNetworking
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("WhatsNewProvider") struct WhatsNewProviderTests {
    private struct Boom: Error {}

    private func release(_ version: String) -> ChangelogRelease {
        ChangelogRelease(version: version, title: "T \(version)", bullets: ["a"])
    }

    @Test func usesFallbackWhenFetchThrows() async {
        let provider = WhatsNewProvider(fetch: { throw Boom() })
        let result = await provider.releases()
        #expect(result == WhatsNewProvider.bundledFallback)
    }

    @Test func usesFallbackWhenFetchReturnsEmpty() async {
        let provider = WhatsNewProvider(fetch: { [] })
        let result = await provider.releases()
        #expect(result == WhatsNewProvider.bundledFallback)
    }

    @Test func networkResultIsSortedNewestFirst() async {
        let items = [release("2.0"), release("2.10"), release("2.9")]
        let provider = WhatsNewProvider(fetch: { items })
        let result = await provider.releases()
        #expect(result.map(\.version) == ["2.10", "2.9", "2.0"])
    }

    @Test func releaseForVersionFallsBackToNewest() async {
        let items = [release("2.0"), release("2.1")]
        let provider = WhatsNewProvider(fetch: { items })
        let exact = await provider.release(for: "2.0")
        let missing = await provider.release(for: "9.9")
        #expect(exact?.version == "2.0")
        #expect(missing?.version == "2.1")
    }
}
