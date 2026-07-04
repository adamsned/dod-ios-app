import Foundation

/// The grocery-ordering providers the app can hand a shopping list off to
/// (DUT-532). The app stays provider-agnostic: it POSTs a
/// `{ provider, title, line_items }` body to a single configured Worker
/// endpoint and opens the returned URL. Each provider's real resolution is a
/// **Worker** concern — Instacart via the IDP `products_link`; Walmart+ via a
/// server-side ingredient → item-id → add-to-cart resolution (Walmart has no
/// open ingredient-list API), or a search deep-link fallback.
public enum GroceryProvider: String, CaseIterable, Sendable {
    case instacart
    case walmartPlus

    /// The wire value sent to the Worker as the `provider` field. Explicit so
    /// the Swift case name (`walmartPlus`) and the snake_case wire contract
    /// (`walmart_plus`) can diverge without surprises.
    public var wireValue: String {
        switch self {
        case .instacart: "instacart"
        case .walmartPlus: "walmart_plus"
        }
    }

    /// The user-facing brand name for the CTA ("Order on <displayName>").
    public var displayName: String {
        switch self {
        case .instacart: "Instacart"
        case .walmartPlus: "Walmart+"
        }
    }

    /// A brand affordance / SF Symbol for the CTA button or menu row. Neither
    /// brand ships a bundled logo yet, so both use a cart glyph; the single-
    /// button path keeps the Instacart glyph the #402 MVP shipped.
    public var systemImage: String {
        switch self {
        case .instacart: "cart.badge.plus"
        case .walmartPlus: "cart.fill.badge.plus"
        }
    }

    /// Parse a Worker wire value (or the config's provider list) back to a case.
    /// Accepts both the `wireValue` (`walmart_plus`) and the raw enum
    /// `rawValue` (`walmartPlus`) plus a couple of friendly aliases so the
    /// gitignored config can be written loosely (e.g. `walmart`).
    public init?(configToken token: String) {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "instacart": self = .instacart
        case "walmart_plus", "walmartplus", "walmart+", "walmart": self = .walmartPlus
        default: return nil
        }
    }
}

/// One line-item in a grocery-order shopping-list page (DUT-532). Provider-
/// agnostic: the Worker forwards these fields verbatim, so the encoded keys
/// keep the Instacart IDP shape — `name` / `quantity` / `unit` / `display_text`
/// (snake_case via ``CodingKeys``).
public struct GroceryLineItem: Encodable, Equatable, Sendable {
    public let name: String
    public let quantity: Double?
    public let unit: String?
    public let displayText: String?

    public init(name: String, quantity: Double? = nil, unit: String? = nil, displayText: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.displayText = displayText
    }

    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case unit
        case displayText = "display_text"
    }
}

/// Failure modes for the grocery-order client. `notConfigured` is the expected
/// pre-deploy state (the CTA is gated off, so production never reaches it); the
/// others surface as a user-facing failure alert on the CTA.
public enum GroceryOrderError: Error, Equatable {
    case notConfigured
    case badURL
    case http(Int)
    case missingLink
}

/// Creates a grocery-order "shopping list page" for a chosen ``GroceryProvider``
/// from the still-need shopping-list rows and returns the shareable link URL
/// (DUT-532). Injectable so the L1 suite + the CTA drive it without the network.
public protocol GroceryOrderLinking: Sendable {
    /// Build the request body from `provider` + `title` + `lineItems`, POST it
    /// to the configured Worker endpoint, and return the returned link URL
    /// (`products_link_url`).
    func createLink(
        provider: GroceryProvider,
        title: String,
        lineItems: [GroceryLineItem]
    ) async throws -> URL
}

/// Production ``GroceryOrderLinking``. Builds the provider-agnostic request
/// body, POSTs JSON to ``GroceryOrderConfig/endpointURLString`` over the
/// injected ``HTTPClient`` (default ``URLSessionHTTPClient`` — inherits the
/// DUT-519 hardened session), and decodes `{ "products_link_url": String }` →
/// `URL`.
///
/// SECURITY (DUT-532): in production the endpoint is a DOD Worker that resolves
/// each provider server-side (injecting the Instacart IDP `Bearer` key, or
/// running the Walmart resolution), so ``GroceryOrderConfig/token`` is `nil` and
/// the app never holds any secret. The token is supported only so a dev build
/// can point straight at a provider's dev server with a dev key for a spike.
///
/// The body shape is unchanged from the #402 Instacart-only client for
/// `provider == .instacart` (same `{ title, line_items }` fields + same Worker),
/// with a new `provider` discriminator added so the Worker can branch.
public struct GroceryOrderClient: GroceryOrderLinking {

    private let config: GroceryOrderConfig
    private let httpClient: any HTTPClient

    public init(
        config: GroceryOrderConfig,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.httpClient = httpClient
    }

    /// The request body shape (see DUT-532): the chosen provider (wire value),
    /// a page title, and the line-items.
    private struct RequestBody: Encodable {
        let provider: String
        let title: String
        let lineItems: [GroceryLineItem]

        enum CodingKeys: String, CodingKey {
            case provider
            case title
            case lineItems = "line_items"
        }
    }

    /// The Worker response: the shareable products-link URL.
    private struct ResponseBody: Decodable {
        let productsLinkURL: String

        enum CodingKeys: String, CodingKey {
            case productsLinkURL = "products_link_url"
        }
    }

    public func createLink(
        provider: GroceryProvider,
        title: String,
        lineItems: [GroceryLineItem]
    ) async throws -> URL {
        guard config.isConfigured else { throw GroceryOrderError.notConfigured }
        guard let url = URL(string: config.endpointURLString) else {
            throw GroceryOrderError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            RequestBody(provider: provider.wireValue, title: title, lineItems: lineItems)
        )

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw GroceryOrderError.http(response.statusCode)
        }
        guard
            let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
            let linkURL = URL(string: decoded.productsLinkURL)
        else {
            throw GroceryOrderError.missingLink
        }
        return linkURL
    }
}
