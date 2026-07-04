import Foundation
import Testing

@testable import DODNetworking

/// L1 coverage for the "Order on Instacart" client (DUT-532) — the app side of
/// the shopping-list → Instacart hand-off. Drives an injected ``FakeHTTPClient``
/// so no network is touched: asserts the POSTed IDP request body shape, the
/// `{ products_link_url }` decoding, the config gate, and the typed errors.
struct InstacartShoppingListClientTests {

    private static let liveConfig = InstacartConfig(
        endpointURLString: "https://worker.example.workers.dev/instacart"
    )

    // MARK: - Config gate

    @Test func isConfiguredFalseForPlaceholder() {
        #expect(InstacartConfig.production.isConfigured == false)
    }

    @Test func isConfiguredFalseForNonHTTPS() {
        #expect(InstacartConfig(endpointURLString: "http://insecure.example").isConfigured == false)
        #expect(InstacartConfig(endpointURLString: "").isConfigured == false)
    }

    @Test func isConfiguredTrueForRealHTTPSEndpoint() {
        #expect(Self.liveConfig.isConfigured == true)
    }

    @Test func createLinkThrowsNotConfiguredWhenDormant() async {
        let client = InstacartShoppingListClient(
            config: .production,
            httpClient: FakeHTTPClient()
        )
        await #expect(throws: InstacartError.notConfigured) {
            _ = try await client.createLink(title: "T", lineItems: [])
        }
    }

    // MARK: - Request encoding

    @Test func postsIDPBodyWithLineItemFieldNames() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "instacart",
            json: Data(#"{"products_link_url":"https://instacart.com/store/x"}"#.utf8)
        )
        let client = InstacartShoppingListClient(config: Self.liveConfig, httpClient: fake)

        _ = try await client.createLink(
            title: "Dutch Oven Daddy Shopping List",
            lineItems: [
                InstacartLineItem(name: "chicken thighs", quantity: 1, unit: "pound", displayText: "1 lb chicken thighs"),
                InstacartLineItem(name: "limes", quantity: 2, unit: nil, displayText: "2 limes"),
            ]
        )

        let request = try #require(await fake.capturedRequests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://worker.example.workers.dev/instacart")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        // Production leaves the token nil (the Worker owns the IDP key), so no
        // Authorization header should ship from the app.
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["title"] as? String == "Dutch Oven Daddy Shopping List")
        let items = try #require(json["line_items"] as? [[String: Any]])
        #expect(items.count == 2)
        #expect(items[0]["name"] as? String == "chicken thighs")
        #expect(items[0]["quantity"] as? Double == 1)
        #expect(items[0]["unit"] as? String == "pound")
        #expect(items[0]["display_text"] as? String == "1 lb chicken thighs")
        // A nil unit is omitted from the encoded item.
        #expect(items[1]["unit"] == nil)
        #expect(items[1]["display_text"] as? String == "2 limes")
    }

    @Test func sendsBearerTokenWhenConfigured() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "dev.instacart",
            json: Data(#"{"products_link_url":"https://instacart.com/x"}"#.utf8)
        )
        let devConfig = InstacartConfig(
            endpointURLString: "https://connect.dev.instacart.tools/idp/v1/products/products_link",
            token: "dev-key-123"
        )
        let client = InstacartShoppingListClient(config: devConfig, httpClient: fake)

        _ = try await client.createLink(title: "T", lineItems: [])

        let request = try #require(await fake.capturedRequests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dev-key-123")
    }

    // MARK: - Response decoding

    @Test func decodesProductsLinkURL() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "instacart",
            json: Data(#"{"products_link_url":"https://www.instacart.com/store/partner/x?ref=dod"}"#.utf8)
        )
        let client = InstacartShoppingListClient(config: Self.liveConfig, httpClient: fake)

        let url = try await client.createLink(title: "T", lineItems: [])
        #expect(url.absoluteString == "https://www.instacart.com/store/partner/x?ref=dod")
    }

    @Test func throwsHTTPOnNon2xx() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "instacart", json: Data("{}".utf8), statusCode: 502)
        let client = InstacartShoppingListClient(config: Self.liveConfig, httpClient: fake)

        await #expect(throws: InstacartError.http(502)) {
            _ = try await client.createLink(title: "T", lineItems: [])
        }
    }

    @Test func throwsMissingLinkWhenURLAbsent() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "instacart", json: Data(#"{"error":"nope"}"#.utf8))
        let client = InstacartShoppingListClient(config: Self.liveConfig, httpClient: fake)

        await #expect(throws: InstacartError.missingLink) {
            _ = try await client.createLink(title: "T", lineItems: [])
        }
    }
}
