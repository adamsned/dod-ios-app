import Foundation
import Testing

@testable import DODNetworking

/// L1 coverage for the provider-agnostic grocery-order client (DUT-532) — the
/// app side of the shopping-list → grocery hand-off. Drives an injected
/// ``FakeHTTPClient`` so no network is touched: asserts the POSTed request body
/// shape (including the `provider` discriminator for Instacart AND Walmart+),
/// the `{ products_link_url }` decoding, the config / provider gate, and the
/// typed errors.
struct GroceryOrderClientTests {

    private static let liveConfig = GroceryOrderConfig(
        endpointURLString: "https://worker.example.workers.dev/grocery",
        providers: [.instacart, .walmartPlus]
    )

    // MARK: - Config gate

    @Test func isConfiguredFalseForPlaceholder() {
        #expect(GroceryOrderConfig.production.isConfigured == false)
    }

    @Test func isConfiguredFalseForNonHTTPS() {
        #expect(GroceryOrderConfig(endpointURLString: "http://insecure.example").isConfigured == false)
        #expect(GroceryOrderConfig(endpointURLString: "").isConfigured == false)
    }

    @Test func isConfiguredTrueForRealHTTPSEndpoint() {
        #expect(Self.liveConfig.isConfigured == true)
    }

    // MARK: - enabledProviders gate

    @Test func enabledProvidersEmptyWhenUnconfigured() {
        // Dormant placeholder → no providers, even if some were listed.
        let config = GroceryOrderConfig(
            endpointURLString: "REPLACE_WITH_GROCERY_ENDPOINT",
            providers: [.instacart, .walmartPlus]
        )
        #expect(config.enabledProviders.isEmpty)
    }

    @Test func enabledProvidersEmptyWhenConfiguredButNoProviders() {
        let config = GroceryOrderConfig(endpointURLString: "https://worker.example.workers.dev")
        #expect(config.enabledProviders.isEmpty)
    }

    @Test func enabledProvidersReflectsConfiguredSet() {
        let single = GroceryOrderConfig(
            endpointURLString: "https://worker.example.workers.dev",
            providers: [.walmartPlus]
        )
        #expect(single.enabledProviders == [.walmartPlus])
        #expect(Self.liveConfig.enabledProviders == [.instacart, .walmartPlus])
    }

    // MARK: - Provider wire values

    @Test func providerWireValues() {
        #expect(GroceryProvider.instacart.wireValue == "instacart")
        #expect(GroceryProvider.walmartPlus.wireValue == "walmart_plus")
    }

    @Test func providerDisplayNames() {
        #expect(GroceryProvider.instacart.displayName == "Instacart")
        #expect(GroceryProvider.walmartPlus.displayName == "Walmart+")
    }

    @Test func providerFromConfigTokenAcceptsAliases() {
        #expect(GroceryProvider(configToken: "instacart") == .instacart)
        #expect(GroceryProvider(configToken: " Walmart_Plus ") == .walmartPlus)
        #expect(GroceryProvider(configToken: "walmart") == .walmartPlus)
        #expect(GroceryProvider(configToken: "kroger") == nil)
    }

    @Test func createLinkThrowsNotConfiguredWhenDormant() async {
        let client = GroceryOrderClient(
            config: .production,
            httpClient: FakeHTTPClient()
        )
        await #expect(throws: GroceryOrderError.notConfigured) {
            _ = try await client.createLink(provider: .instacart, title: "T", lineItems: [])
        }
    }

    // MARK: - Request encoding (Instacart — unchanged #402 body shape + provider)

    @Test func postsInstacartBodyWithProviderAndLineItemFieldNames() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "grocery",
            json: Data(#"{"products_link_url":"https://instacart.com/store/x"}"#.utf8)
        )
        let client = GroceryOrderClient(config: Self.liveConfig, httpClient: fake)

        _ = try await client.createLink(
            provider: .instacart,
            title: "Dutch Oven Daddy Shopping List",
            lineItems: [
                GroceryLineItem(name: "chicken thighs", quantity: 1, unit: "pound", displayText: "1 lb chicken thighs"),
                GroceryLineItem(name: "limes", quantity: 2, unit: nil, displayText: "2 limes"),
            ]
        )

        let request = try #require(await fake.capturedRequests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://worker.example.workers.dev/grocery")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        // Production leaves the token nil (the Worker owns the provider keys), so
        // no Authorization header should ship from the app.
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["provider"] as? String == "instacart")
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

    // MARK: - Request encoding (Walmart+ — provider: "walmart_plus")

    @Test func postsWalmartBodyWithWalmartPlusProvider() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "grocery",
            json: Data(#"{"products_link_url":"https://affil.walmart.com/cart/addToCart?items=x"}"#.utf8)
        )
        let client = GroceryOrderClient(config: Self.liveConfig, httpClient: fake)

        let url = try await client.createLink(
            provider: .walmartPlus,
            title: "Dutch Oven Daddy Shopping List",
            lineItems: [
                GroceryLineItem(name: "beef chuck roast", quantity: 3, unit: "pound", displayText: "3 lb beef chuck roast")
            ]
        )
        #expect(url.absoluteString == "https://affil.walmart.com/cart/addToCart?items=x")

        let request = try #require(await fake.capturedRequests.first)
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // The provider discriminator lets the Worker branch to its Walmart
        // resolution (ingredient → item id → add-to-cart link).
        #expect(json["provider"] as? String == "walmart_plus")
        #expect(json["title"] as? String == "Dutch Oven Daddy Shopping List")
        let items = try #require(json["line_items"] as? [[String: Any]])
        #expect(items.count == 1)
        #expect(items[0]["name"] as? String == "beef chuck roast")
        #expect(items[0]["display_text"] as? String == "3 lb beef chuck roast")
    }

    @Test func sendsBearerTokenWhenConfigured() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "dev.instacart",
            json: Data(#"{"products_link_url":"https://instacart.com/x"}"#.utf8)
        )
        let devConfig = GroceryOrderConfig(
            endpointURLString: "https://connect.dev.instacart.tools/idp/v1/products/products_link",
            token: "dev-key-123",
            providers: [.instacart]
        )
        let client = GroceryOrderClient(config: devConfig, httpClient: fake)

        _ = try await client.createLink(provider: .instacart, title: "T", lineItems: [])

        let request = try #require(await fake.capturedRequests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dev-key-123")
    }

    // MARK: - Response decoding

    @Test func decodesProductsLinkURL() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "grocery",
            json: Data(#"{"products_link_url":"https://www.instacart.com/store/partner/x?ref=dod"}"#.utf8)
        )
        let client = GroceryOrderClient(config: Self.liveConfig, httpClient: fake)

        let url = try await client.createLink(provider: .instacart, title: "T", lineItems: [])
        #expect(url.absoluteString == "https://www.instacart.com/store/partner/x?ref=dod")
    }

    @Test func throwsHTTPOnNon2xx() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "grocery", json: Data("{}".utf8), statusCode: 502)
        let client = GroceryOrderClient(config: Self.liveConfig, httpClient: fake)

        await #expect(throws: GroceryOrderError.http(502)) {
            _ = try await client.createLink(provider: .instacart, title: "T", lineItems: [])
        }
    }

    @Test func throwsMissingLinkWhenURLAbsent() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "grocery", json: Data(#"{"error":"nope"}"#.utf8))
        let client = GroceryOrderClient(config: Self.liveConfig, httpClient: fake)

        await #expect(throws: GroceryOrderError.missingLink) {
            _ = try await client.createLink(provider: .walmartPlus, title: "T", lineItems: [])
        }
    }
}
