import Foundation
import Testing

@testable import DODNetworking

@Suite("WPChangelogClient.releases") struct WPChangelogClientTests {

    @Test func decodesReleasesIncludingOptionalHeroImage() async throws {
        let json = #"""
            [{"version":"2.1","title":"Hi","bullets":["a","b"],"hero_image_url":"https://x.test/h.png"},
             {"version":"2.0","title":"Old","bullets":["c"]}]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "changelog", json: Data(json.utf8))
        let client = WPChangelogClient(httpClient: fake)

        let releases = try await client.releases()
        #expect(releases.count == 2)
        #expect(releases[0].version == "2.1")
        #expect(releases[0].heroImageURL != nil)
        #expect(releases[1].heroImageURL == nil)
    }

    @Test func throwsOnNon2xx() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "changelog", json: Data("[]".utf8), statusCode: 500)
        let client = WPChangelogClient(httpClient: fake)

        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await client.releases()
        }
    }
}
