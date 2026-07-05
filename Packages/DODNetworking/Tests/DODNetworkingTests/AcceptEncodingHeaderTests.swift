import Foundation
import Testing

@testable import DODNetworking

/// DUT-578: the module must NOT set a manual `Accept-Encoding: gzip` header.
/// URLSession only performs TRANSPARENT response decompression when it owns
/// that header; when the app sets it, the caller becomes responsible for
/// gunzipping a `Content-Encoding: gzip` body — and there is no gunzip in this
/// module. Removing the header lets URLSession negotiate + decompress, so a
/// gzipped body arrives already-inflated and every fetch decodes normally.
///
/// The FakeHTTPClient passes bytes through unchanged (it is not URLSession), so
/// these tests assert the observable contract at the client seam: (1) no
/// outgoing request carries `Accept-Encoding`, and (2) a normal (already-plain)
/// response still decodes end-to-end with the header removed.
@Suite("Accept-Encoding header removed (DUT-578)") struct AcceptEncodingHeaderTests {

    private let postsFixture = """
        [
          {
            "id": 1,
            "slug": "corn",
            "link": "https://www.dutchovendaddy.com/corn/",
            "title": { "rendered": "Corn" },
            "excerpt": { "rendered": "<p>Side.</p>" }
          }
        ]
        """

    @Test func restGetOmitsAcceptEncoding() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(postsFixture.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()
        #expect(items.count == 1)  // normal response still decodes

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == nil)
    }

    @Test func commentsGetOmitsAcceptEncoding() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data("[]".utf8))
        let client = WPCommentsClient(httpClient: fake)

        _ = try await client.comments(forPostID: 1)

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == nil)
    }

    @Test func ratingsGetOmitsAcceptEncoding() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating", json: Data("{\"average\":4.5,\"count\":10}".utf8))
        let client = WPRMRatingsClient(httpClient: fake)

        _ = try await client.summary(forRecipeID: 1)

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == nil)
    }

    @Test func htmlFetchOmitsAcceptEncoding() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", html: "<html><body>ok</body></html>")
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        let html = try await fetcher.html(for: url)
        #expect(html.contains("ok"))  // normal response still decodes

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == nil)
    }
}
