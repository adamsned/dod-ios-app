import Foundation

/// Configuration for the **Instacart "Order on Instacart" endpoint** (DUT-532):
/// the URL the app POSTs the shopping-list line-items to, plus an optional
/// `Bearer` token.
///
/// The Instacart Developer Platform (IDP) key is a **server secret** — it must
/// NOT ship in the app. So production points ``endpointURLString`` at a DOD
/// Cloudflare Worker that injects the real IDP `Authorization: Bearer <key>`
/// and forwards to `POST https://connect.instacart.com/idp/v1/products/products_link`;
/// the app never holds the key (``token`` stays `nil`). A dev spike MAY point
/// ``endpointURLString`` straight at the IDP dev server
/// (`https://connect.dev.instacart.tools/idp/v1/products/products_link`) and set
/// ``token`` to a dev key — but that path is for local experiments only.
///
/// Mirrors ``SiwaRevokeConfig`` (DUT-98) + `GoogleSignInConfig`: the owner fills
/// ``production`` in after the Worker deploys. Until then ``isConfigured`` is
/// `false`, so the "Order on Instacart" CTA stays HIDDEN — the app ships this
/// feature DORMANT, exactly as the SiwA revoke client shipped ahead of its
/// Worker.
public struct InstacartConfig: Sendable {

    /// The endpoint the app POSTs the IDP request body to (the Worker in
    /// production; the IDP dev server for a dev spike).
    public let endpointURLString: String
    /// Optional `Bearer` token. Production leaves this `nil` (the Worker owns the
    /// secret); a dev build MAY set a dev IDP key to hit the dev server directly.
    public let token: String?

    public init(endpointURLString: String, token: String? = nil) {
        self.endpointURLString = endpointURLString
        self.token = token
    }

    /// Replace ``endpointURLString`` after deploying the Worker. The placeholder
    /// is a sentinel — ``isConfigured`` stays `false` while it's present, so the
    /// CTA stays hidden and production ships dormant.
    ///
    /// Do NOT hardcode a real Worker URL or IDP key here — the real endpoint
    /// belongs in a gitignored xcconfig-backed Info.plist key
    /// (`DODInstacartEndpoint`), read via ``fromInfoPlist(_:)`` at app-wiring
    /// time. This constant is only the compile-time fallback.
    public static let production = InstacartConfig(
        endpointURLString: "REPLACE_WITH_INSTACART_ENDPOINT",
        token: nil
    )

    /// Build a config from the app's Info.plist (xcconfig-backed, gitignored):
    /// `DODInstacartEndpoint` = the endpoint URL, `DODInstacartToken` = an
    /// optional dev `Bearer` token. Returns ``production`` (the dormant
    /// placeholder) when the endpoint key is absent, so an un-provisioned build
    /// stays dormant.
    public static func fromInfoPlist(
        _ bundle: Bundle = .main
    ) -> InstacartConfig {
        guard
            let endpoint = bundle.object(forInfoDictionaryKey: "DODInstacartEndpoint") as? String,
            !endpoint.isEmpty
        else {
            return .production
        }
        let token = bundle.object(forInfoDictionaryKey: "DODInstacartToken") as? String
        return InstacartConfig(
            endpointURLString: endpoint,
            token: (token?.isEmpty ?? true) ? nil : token
        )
    }

    /// `true` only once a real `https` endpoint is set (the Worker is live, or a
    /// dev server URL is wired). Drives whether the "Order on Instacart" CTA is
    /// shown — hidden while dormant.
    public var isConfigured: Bool {
        endpointURLString.hasPrefix("https://") && !endpointURLString.hasPrefix("REPLACE")
    }
}

/// One line-item in an Instacart shopping-list page (DUT-532). Encodes to the
/// IDP `line_items[]` field names — note `display_text` (snake_case) via
/// ``CodingKeys``.
public struct InstacartLineItem: Encodable, Equatable, Sendable {
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

/// Failure modes for the Instacart shopping-list client. `notConfigured` is the
/// expected pre-deploy state (the CTA is gated off, so production never reaches
/// it); the others surface as a user-facing failure alert on the CTA.
public enum InstacartError: Error, Equatable {
    case notConfigured
    case badURL
    case http(Int)
    case missingLink
}

/// Creates an Instacart "shopping list page" from the still-need shopping-list
/// rows and returns the shareable `products_link_url` (DUT-532). Injectable so
/// the L1 suite + the CTA drive it without the network.
public protocol InstacartShoppingListLinking: Sendable {
    /// Build the IDP request body from `title` + `lineItems`, POST it to the
    /// configured endpoint, and return the returned `products_link_url`.
    func createLink(title: String, lineItems: [InstacartLineItem]) async throws -> URL
}

/// Production ``InstacartShoppingListLinking``. Builds the IDP request body,
/// POSTs JSON to ``InstacartConfig/endpointURLString`` over the injected
/// ``HTTPClient`` (default ``URLSessionHTTPClient`` — inherits the DUT-519
/// hardened session), and decodes `{ "products_link_url": String }` → `URL`.
///
/// SECURITY (DUT-532): in production the endpoint is a DOD Worker that injects
/// the IDP `Bearer` key server-side, so ``InstacartConfig/token`` is `nil` and
/// the app never holds the secret. The token is supported only so a dev build
/// can point straight at the IDP dev server with a dev key for a spike.
public struct InstacartShoppingListClient: InstacartShoppingListLinking {

    private let config: InstacartConfig
    private let httpClient: any HTTPClient

    public init(
        config: InstacartConfig,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.httpClient = httpClient
    }

    /// The IDP request body shape (see DUT-532): a page title + the line-items.
    private struct RequestBody: Encodable {
        let title: String
        let lineItems: [InstacartLineItem]

        enum CodingKeys: String, CodingKey {
            case title
            case lineItems = "line_items"
        }
    }

    /// The IDP response: the shareable products-link URL.
    private struct ResponseBody: Decodable {
        let productsLinkURL: String

        enum CodingKeys: String, CodingKey {
            case productsLinkURL = "products_link_url"
        }
    }

    public func createLink(title: String, lineItems: [InstacartLineItem]) async throws -> URL {
        guard config.isConfigured else { throw InstacartError.notConfigured }
        guard let url = URL(string: config.endpointURLString) else {
            throw InstacartError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            RequestBody(title: title, lineItems: lineItems)
        )

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw InstacartError.http(response.statusCode)
        }
        guard
            let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
            let linkURL = URL(string: decoded.productsLinkURL)
        else {
            throw InstacartError.missingLink
        }
        return linkURL
    }
}
