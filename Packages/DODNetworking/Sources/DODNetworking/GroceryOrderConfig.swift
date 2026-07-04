import Foundation

/// Configuration for the **grocery-ordering endpoint** (DUT-532): the URL the
/// app POSTs the shopping-list `{ provider, title, line_items }` body to, an
/// optional `Bearer` token, and which ``GroceryProvider``s are enabled.
///
/// The provider secrets (the Instacart IDP key, the Walmart.io key) are
/// **server secrets** — they must NOT ship in the app. So production points
/// ``endpointURLString`` at a DOD Cloudflare Worker that resolves each provider
/// server-side and the app never holds a key (``token`` stays `nil`). A dev
/// spike MAY point ``endpointURLString`` straight at a provider dev server and
/// set ``token`` to a dev key — that path is for local experiments only.
///
/// Mirrors ``SiwaRevokeConfig`` (DUT-98) + `GoogleSignInConfig`: the owner fills
/// the gitignored Info.plist keys in after the Worker deploys. Until then
/// ``enabledProviders`` is empty, so the "Order ingredients" CTA stays HIDDEN —
/// the app ships this feature DORMANT, exactly as the SiwA revoke client shipped
/// ahead of its Worker.
public struct GroceryOrderConfig: Sendable {

    /// The endpoint the app POSTs the order request body to (the Worker in
    /// production; a provider dev server for a dev spike).
    public let endpointURLString: String
    /// Optional `Bearer` token. Production leaves this `nil` (the Worker owns the
    /// secrets); a dev build MAY set a dev key to hit a dev server directly.
    public let token: String?
    /// The providers the owner has switched on. Empty by default (unconfigured →
    /// CTA hidden). Drives whether the CTA shows nothing, a single button, or a
    /// provider menu.
    public let providers: [GroceryProvider]

    public init(
        endpointURLString: String,
        token: String? = nil,
        providers: [GroceryProvider] = []
    ) {
        self.endpointURLString = endpointURLString
        self.token = token
        self.providers = providers
    }

    /// Replace ``endpointURLString`` after deploying the Worker. The placeholder
    /// is a sentinel — ``isConfigured`` stays `false` while it's present, so the
    /// CTA stays hidden and production ships dormant.
    ///
    /// Do NOT hardcode a real Worker URL or provider key here — the real
    /// endpoint belongs in gitignored xcconfig-backed Info.plist keys
    /// (`DODGroceryEndpoint`, `DODGroceryProviders`), read via
    /// ``fromInfoPlist(_:)`` at app-wiring time. This constant is only the
    /// compile-time fallback and ships with NO providers enabled.
    public static let production = GroceryOrderConfig(
        endpointURLString: "REPLACE_WITH_GROCERY_ENDPOINT",
        token: nil,
        providers: []
    )

    /// Build a config from the app's Info.plist (xcconfig-backed, gitignored):
    /// - `DODGroceryEndpoint` = the Worker endpoint URL.
    /// - `DODGroceryToken` = an optional dev `Bearer` token.
    /// - `DODGroceryProviders` = a comma-separated provider list
    ///   (e.g. `instacart,walmart_plus`). Per-provider convenience flags
    ///   `DODInstacartEnabled` / `DODWalmartEnabled` (YES/true/1) are also
    ///   honored and merged in.
    ///
    /// Returns ``production`` (the dormant placeholder, no providers) when the
    /// endpoint key is absent, so an un-provisioned build stays dormant.
    public static func fromInfoPlist(
        _ bundle: Bundle = .main
    ) -> GroceryOrderConfig {
        guard
            let endpoint = bundle.object(forInfoDictionaryKey: "DODGroceryEndpoint") as? String,
            !endpoint.isEmpty
        else {
            return .production
        }
        let token = bundle.object(forInfoDictionaryKey: "DODGroceryToken") as? String
        return GroceryOrderConfig(
            endpointURLString: endpoint,
            token: (token?.isEmpty ?? true) ? nil : token,
            providers: providers(from: bundle)
        )
    }

    /// Parse the enabled-provider set from the gitignored plist keys: the
    /// `DODGroceryProviders` comma list plus the per-provider boolean flags,
    /// de-duplicated in ``GroceryProvider/allCases`` order for a stable CTA
    /// ordering.
    private static func providers(from bundle: Bundle) -> [GroceryProvider] {
        var enabled = Set<GroceryProvider>()

        if let list = bundle.object(forInfoDictionaryKey: "DODGroceryProviders") as? String {
            for token in list.split(separator: ",") {
                if let provider = GroceryProvider(configToken: String(token)) {
                    enabled.insert(provider)
                }
            }
        }
        if boolFlag(bundle, key: "DODInstacartEnabled") { enabled.insert(.instacart) }
        if boolFlag(bundle, key: "DODWalmartEnabled") { enabled.insert(.walmartPlus) }

        return GroceryProvider.allCases.filter(enabled.contains)
    }

    /// Read a plist flag as a bool. Accepts a real `Bool`/`NSNumber` value or a
    /// string (`YES` / `true` / `1`), since xcconfig-backed Info.plist values
    /// arrive as strings.
    private static func boolFlag(_ bundle: Bundle, key: String) -> Bool {
        switch bundle.object(forInfoDictionaryKey: key) {
        case let value as Bool: return value
        case let value as NSNumber: return value.boolValue
        case let value as String:
            return ["yes", "true", "1"].contains(value.trimmingCharacters(in: .whitespaces).lowercased())
        default: return false
        }
    }

    /// `true` only once a real `https` endpoint is set (the Worker is live, or a
    /// dev server URL is wired). A prerequisite for the CTA — but the CTA also
    /// needs at least one enabled provider (see ``enabledProviders``).
    public var isConfigured: Bool {
        endpointURLString.hasPrefix("https://") && !endpointURLString.hasPrefix("REPLACE")
    }

    /// The providers the CTA should actually offer: the configured ``providers``
    /// but only when the endpoint ``isConfigured``. Empty when the endpoint is
    /// the dormant placeholder OR no providers are switched on — either way the
    /// CTA stays hidden, so production ships dormant.
    public var enabledProviders: [GroceryProvider] {
        isConfigured ? providers : []
    }
}
