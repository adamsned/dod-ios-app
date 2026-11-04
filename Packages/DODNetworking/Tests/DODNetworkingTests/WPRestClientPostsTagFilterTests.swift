import Foundation
import Testing

@testable import DODNetworking

@Suite("WPRestClient.postsPage tag filter")
struct WPRestClientPostsTagFilterTests {

    private func stubbedClient() async -> (client: WPRestClient, fake: FakeHTTPClient) {
        let body = Data("[]".utf8)
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json", "X-WP-TotalPages": "1"]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (body, response)
        }
        return (WPRestClient(httpClient: fake), fake)
    }

    @Test func postsPageSendsCommaJoinedTagsParam() async throws {
        let (client, fake) = await stubbedClient()
        _ = try await client.postsPage(tagIDs: [7, 9])

        let recordedRequest = await fake.capturedRequests.first
        #expect(recordedRequest?.url?.query?.contains("tags=7,9") == true)
    }

    @Test func postsPageOmitsTagsParamWhenEmpty() async throws {
        let (client, fake) = await stubbedClient()
        _ = try await client.postsPage(tagIDs: [])

        let recordedRequest = await fake.capturedRequests.first
        #expect(recordedRequest?.url?.query?.contains("tags=") == false)
    }
}
