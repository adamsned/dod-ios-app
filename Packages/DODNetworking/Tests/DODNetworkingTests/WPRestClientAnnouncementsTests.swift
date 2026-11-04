import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("WPRestClient.announcements (DUT-147)")
struct WPRestClientAnnouncementsTests {

    private let json = """
        [
          {"id": 1, "date_gmt": "2026-10-01T12:00:00",
           "title": {"rendered": "Shop &amp; Save"},
           "content": {"rendered": "<p>Visit <a href=\\"https://buzzywaxx.com/shop\\">the shop</a></p>"}},
          {"id": 2, "date_gmt": "2026-09-01T12:00:00",
           "title": {"rendered": "Plain post"},
           "content": {"rendered": "<p>No links here</p>"}}
        ]
        """

    @Test func decodesAnnouncementsAndSendsCategory() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(json.utf8))
        let client = WPRestClient(httpClient: fake)

        let result = try await client.announcements(categoryID: 7)

        #expect(result.count == 2)
        #expect(result[0].title == "Shop & Save")
        if case .shop = result[0].deepLink {
        } else {
            Issue.record("expected .shop, got \(String(describing: result[0].deepLink))")
        }
        #expect(result[1].deepLink == nil)
        let urls = await fake.capturedRequests.compactMap { $0.url?.absoluteString }
        #expect(urls.contains { $0.contains("categories=7") })
    }

    @Test func rethrowsNetworkUnavailable() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts") { _ in throw WPClientError.networkUnavailable }
        let client = WPRestClient(httpClient: fake)

        await #expect(throws: WPClientError.networkUnavailable) {
            _ = try await client.announcements(categoryID: 7)
        }
    }
}
