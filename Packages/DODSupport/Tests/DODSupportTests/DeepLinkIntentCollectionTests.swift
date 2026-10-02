import Foundation
import Testing

@testable import DODSupport

/// DUT-1388 — `dod://collection?id=<uuid>` (Siri "Open my <name> collection").
@Suite("DeepLinkIntent collection route (DUT-1388)") struct DeepLinkIntentCollectionTests {

    private let id = UUID(
        uuid: (0x6F, 0x1C, 0x2B, 0x0A, 0x1D, 0x2E, 0x4F, 0x3A, 0x9B, 0x8C, 0x7D, 0x6E, 0x5F, 0x4A, 0x3B, 0x2C)
    )

    @Test func queryFormParses() throws {
        let url = try #require(URL(string: "dod://collection?id=\(id.uuidString)"))
        #expect(DeepLinkIntent.parse(url) == .openCollection(id: id))
    }

    @Test func pathFormParses() throws {
        let url = try #require(URL(string: "dod://collection/\(id.uuidString)"))
        #expect(DeepLinkIntent.parse(url) == .openCollection(id: id))
    }

    @Test func uppercaseSchemeAndHostParse() throws {
        let url = try #require(URL(string: "DOD://COLLECTION?id=\(id.uuidString)"))
        #expect(DeepLinkIntent.parse(url) == .openCollection(id: id))
    }

    @Test func nonUUIDIsRejected() throws {
        #expect(DeepLinkIntent.parse(try #require(URL(string: "dod://collection?id=42"))) == nil)
        #expect(DeepLinkIntent.parse(try #require(URL(string: "dod://collection"))) == nil)
    }

    @Test func otherSchemeIsRejected() throws {
        let url = try #require(URL(string: "https://collection?id=\(id.uuidString)"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    @Test func urlRoundTrips() {
        let intent = DeepLinkIntent.openCollection(id: id)
        #expect(DeepLinkIntent.parse(intent.url) == intent)
    }

    /// The existing routes are untouched by the collection pre-parse.
    @Test func existingRoutesStillParse() throws {
        #expect(DeepLinkIntent.parse(try #require(URL(string: "dod://saved"))) == .openSaved)
        #expect(DeepLinkIntent.parse(try #require(URL(string: "dod://recipe?id=7"))) == .openRecipe(id: 7))
    }
}
