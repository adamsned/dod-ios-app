import Foundation
import Testing

@testable import DODNetworking

/// DUT-575: one malformed post must not empty the whole feed / category /
/// search page. The `[Post]` array is decoded lossily (`LossyArray`) and
/// `title`/`excerpt` are lenient, so a `title: null` row is skipped/repaired
/// rather than throwing `.decoding` for the entire page.
@Suite("WPRestClient.posts lossy decode (DUT-575)") struct WPPostLossyDecodeTests {

    /// A 3-post page whose MIDDLE row has `title: null` — the exact draft-state /
    /// ACF-edge shape that previously nuked the page. The two good rows must
    /// survive; the middle row is repaired (empty title) rather than dropped,
    /// because `title` is decoded leniently.
    private let pageWithNullTitle = """
        [
          {
            "id": 1,
            "slug": "good-one",
            "link": "https://www.dutchovendaddy.com/good-one/",
            "title": { "rendered": "Good One" },
            "excerpt": { "rendered": "<p>First.</p>" }
          },
          {
            "id": 2,
            "slug": "null-title",
            "link": "https://www.dutchovendaddy.com/null-title/",
            "title": null,
            "excerpt": { "rendered": "<p>Second.</p>" }
          },
          {
            "id": 3,
            "slug": "good-three",
            "link": "https://www.dutchovendaddy.com/good-three/",
            "title": { "rendered": "Good Three" },
            "excerpt": { "rendered": "<p>Third.</p>" }
          }
        ]
        """

    @Test func nullTitleRowDoesNotEmptyThePage() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(pageWithNullTitle.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        // Before the fix this returned [] (whole-page decode failure). Now the
        // two clean rows AND the leniently-repaired null-title row all survive.
        #expect(items.count == 3)
        #expect(items.map { $0.id } == [1, 2, 3])
        let repaired = try #require(items.first { $0.id == 2 })
        #expect(repaired.title.isEmpty)
        #expect(repaired.excerpt == "Second.")
    }

    /// A wholly mis-shaped row (missing the required `id`) is DROPPED by the
    /// lossy array decode, but the good rows around it still render — the
    /// collection-level resilience on top of per-field leniency.
    private let pageWithUnusableRow = """
        [
          {
            "id": 10,
            "slug": "keep-me",
            "link": "https://www.dutchovendaddy.com/keep-me/",
            "title": { "rendered": "Keep Me" },
            "excerpt": { "rendered": "<p>Kept.</p>" }
          },
          {
            "slug": "no-id",
            "title": { "rendered": "No ID" },
            "excerpt": { "rendered": "<p>Unusable.</p>" }
          },
          {
            "id": 11,
            "slug": "keep-me-too",
            "link": "https://www.dutchovendaddy.com/keep-me-too/",
            "title": { "rendered": "Keep Me Too" },
            "excerpt": { "rendered": "<p>Also kept.</p>" }
          }
        ]
        """

    @Test func rowMissingRequiredIDIsDroppedButPageSurvives() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(pageWithUnusableRow.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(items.map { $0.id } == [10, 11])
    }

    @Test func searchPathIsAlsoLossy() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(pageWithNullTitle.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.search(query: "corn")

        #expect(items.count == 3)
    }
}
