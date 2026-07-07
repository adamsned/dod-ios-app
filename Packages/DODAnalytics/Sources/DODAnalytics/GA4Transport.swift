import CryptoKit
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Secondary telemetry transport that mirrors in-app **content opens**
/// (recipe / article detail views) into Google Analytics 4 via the
/// Measurement Protocol, so opens performed inside the native app show up
/// alongside the website's GA4 traffic (DUT-680).
///
/// **Scope is deliberately narrow.** Unlike ``TelemetryDeckTransport`` (which
/// forwards every allowlisted event), this transport only maps the
/// content-OPEN events — a recipe/article detail appearing on screen — to a
/// single GA4 `recipe_open` event. Every other event (`appOpen`,
/// `screenView`, saves, searches, sync, …) is ignored and never sent to
/// Google. GA4 is a **content-traffic** measurement surface here, not a
/// full product-analytics pipe.
///
/// **No PII, no personal data (constitution §9).** The GA4 event params carry
/// only the WordPress post id and the canonical URL host + path of the
/// content — never user input, never a raw device identifier. The GA4
/// `client_id` is a *salted pseudonymous* id (reusing DUT-669's
/// ``TelemetryDeckTransport/pseudonymSalt``), NOT a new device fingerprint.
///
/// **Config-gated (no-op by default).** The Measurement ID + API secret are
/// read from the app's Info.plist (sourced from the gitignored `DODApp.xcconfig`
/// → `GA4MeasurementID` / `GA4APISecret`). When EITHER is nil/empty — dev
/// builds, PR builds, any unconfigured build — the transport no-ops and never
/// touches the network. This mirrors how ``TelemetryDeckTransport`` skips when
/// its app id is unset.
///
/// **Privacy opt-out gate (US-36 / AC-36.5 / AC-36.6).** Sending content-views
/// to Google IS data collection, so every send re-reads the SAME
/// "Share anonymous usage data" preference the TelemetryDeck transport uses
/// (`UserDefaults` key ``TelemetryDeckTransport/telemetryEnabledKey``,
/// default-ON). A user who opted out sends NOTHING to GA4.
///
/// Spec trace: DUT-680 — GA4 Measurement Protocol transport.
public final class GA4Transport: TelemetryTransport, @unchecked Sendable {

    /// GA4 Measurement Protocol collection endpoint. The `measurement_id` +
    /// `api_secret` are attached as query items when the request is built.
    static let collectEndpoint = "https://www.google-analytics.com/mp/collect"

    /// The single GA4 event name every content-open maps to.
    static let ga4EventName = "recipe_open"

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let measurementID: String?
    private let apiSecret: String?
    private let clientID: String
    private let post: (URLRequest) -> Void

    /// Production initializer. Reads GA4 creds from the app's Info.plist and
    /// derives the pseudonymous `client_id`. When either cred is missing the
    /// transport is inert.
    ///
    /// - Parameters:
    ///   - defaults: privacy-toggle store; `.standard` in production, an
    ///     isolated suite in L1 tests.
    ///   - bundle: Info.plist source; `.main` in production.
    ///   - session: the URLSession used to POST; `.shared` in production.
    public convenience init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        session: URLSession = .shared
    ) {
        let measurementID = (bundle.object(forInfoDictionaryKey: "GA4MeasurementID") as? String)
        let apiSecret = (bundle.object(forInfoDictionaryKey: "GA4APISecret") as? String)
        self.init(
            defaults: defaults,
            measurementID: measurementID,
            apiSecret: apiSecret,
            clientID: Self.pseudonymousClientID(),
            post: { request in session.dataTask(with: request).resume() }
        )
    }

    /// Designated / test initializer. Everything the production path resolves
    /// from the environment (creds, client id, the network sink) is injected
    /// here so L1 tests can assert the no-op, opt-out, and request-shape
    /// contracts without real network or a real bundle.
    init(
        defaults: UserDefaults,
        measurementID: String?,
        apiSecret: String?,
        clientID: String,
        post: @escaping (URLRequest) -> Void
    ) {
        self.defaults = defaults
        self.measurementID = measurementID
        self.apiSecret = apiSecret
        self.clientID = clientID
        self.post = post
    }

    /// GA4 has no per-app "app id" the way TelemetryDeck does — its creds come
    /// from Info.plist at init. `configure` is a no-op required by the protocol.
    public func configure(appID: String) {}

    public func send(_ event: AnalyticsEvent) {
        // (1) Config gate: no Measurement ID / API secret -> inert. Dev + PR +
        // unconfigured builds send nothing. Mirrors TelemetryDeck's unset-appID skip.
        guard
            let measurementID, !measurementID.isEmpty,
            let apiSecret, !apiSecret.isEmpty
        else { return }

        // (2) Privacy opt-out gate (US-36): re-read the SAME toggle
        // TelemetryDeck uses, default-ON. Opted out -> nothing leaves the device.
        guard isTelemetryEnabled() else { return }

        // (3) Scope gate: only content-OPEN events map to GA4; everything else
        // is ignored by this transport.
        guard let ga4Event = Self.ga4Event(for: event) else { return }

        guard
            let request = Self.makeCollectRequest(
                measurementID: measurementID,
                apiSecret: apiSecret,
                clientID: clientID,
                event: ga4Event
            )
        else { return }

        lock.lock()
        let post = self.post
        lock.unlock()
        post(request)
    }

    // MARK: - Pure request construction (testable)

    /// A single GA4 event: a name plus string-keyed params. Deliberately
    /// PII-free — only the post id and canonical URL host/path.
    struct GA4Event: Equatable {
        let name: String
        let params: [String: String]
    }

    /// Map an ``AnalyticsEvent`` to a GA4 content-open event, or `nil` when the
    /// event is not a content open (so the caller ignores it).
    ///
    /// Content-open events are the recipe/article detail appearing on screen:
    /// ``AnalyticsEvent/recipeView(recipeID:)`` (online) and
    /// ``AnalyticsEvent/offlineRead(recipeID:)`` (a saved recipe opened while
    /// offline). Both are the same "user opened this content" signal for GA4.
    static func ga4Event(for event: AnalyticsEvent) -> GA4Event? {
        let recipeID: Int
        switch event {
        case .recipeView(let id), .offlineRead(let id):
            recipeID = id
        default:
            // Not a content open — TelemetryDeck still records it, GA4 ignores it.
            return nil
        }

        var params: [String: String] = ["post_id": String(recipeID)]
        // Canonical URL host + path for the content (no query, no PII). Lets
        // GA4 line the in-app open up with the same page on the website.
        if let components = canonicalURLComponents(recipeID: recipeID) {
            params["page_host"] = components.host
            params["page_path"] = components.path
        }
        return GA4Event(name: ga4EventName, params: params)
    }

    /// Canonical website host + path for a recipe/article post id. The DOD
    /// website serves posts under `/?p=<id>` on the canonical host, which
    /// resolves to the pretty permalink server-side. Host + path only — no
    /// query string with user data, no PII.
    static func canonicalURLComponents(recipeID: Int) -> (host: String, path: String)? {
        ("dutchovendaddy.com", "/recipe/\(recipeID)")
    }

    /// Build the `/mp/collect` POST request for a GA4 event. Pure + testable:
    /// given creds + client id + event it returns the exact `URLRequest`
    /// (URL with `measurement_id` + `api_secret` query items, JSON body of
    /// `{ client_id, events: [{ name, params }] }`). Returns `nil` only if the
    /// URL or JSON can't be formed.
    static func makeCollectRequest(
        measurementID: String,
        apiSecret: String,
        clientID: String,
        event: GA4Event
    ) -> URLRequest? {
        guard var components = URLComponents(string: collectEndpoint) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "measurement_id", value: measurementID),
            URLQueryItem(name: "api_secret", value: apiSecret),
        ]
        guard let url = components.url else { return nil }

        // GA4 Measurement Protocol body: a client_id plus an events array.
        // Params are string-valued (no PII) so a [String: String] map is the
        // exact wire shape; encode with sorted keys for a stable body.
        let body: [String: Any] = [
            "client_id": clientID,
            "events": [
                ["name": event.name, "params": event.params]
            ],
        ]
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: body,
                options: [.sortedKeys]
            )
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return request
    }

    // MARK: - client_id

    /// A stable, salted, pseudonymous `client_id` for GA4 — NOT a new device
    /// fingerprint. Reuses DUT-669's ``TelemetryDeckTransport/pseudonymSalt``
    /// and the vendor identifier (the same inputs TelemetryDeck salts into its
    /// pseudonym), hashed so the raw identifier never leaves the device. On
    /// platforms without `identifierForVendor` (the macOS L1 test host) it
    /// falls back to a per-run UUID, which is fine because GA4 is never wired
    /// up in tests.
    static func pseudonymousClientID() -> String {
        #if canImport(UIKit)
        let vendorID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let vendorID = UUID().uuidString
        #endif
        return saltedPseudonym(vendorID)
    }

    /// Salt + hash a raw identifier into a hex pseudonym. Uses the same salt
    /// constant as the TelemetryDeck pseudonym so GA4 and TelemetryDeck share
    /// the DUT-669 privacy posture (no unsalted device-id hash on the wire).
    static func saltedPseudonym(_ rawID: String) -> String {
        let salted = TelemetryDeckTransport.pseudonymSalt + rawID
        return Self.sha256Hex(salted)
    }

    /// Lowercase hex SHA-256 of a string. Uses Apple's `CryptoKit` (already an
    /// exempt-encryption framework per `ITSAppUsesNonExemptEncryption = false`).
    static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Read the user's privacy toggle, defaulting to `true` when absent — the
    /// EXACT same read ``TelemetryDeckTransport`` performs, against the same
    /// `UserDefaults` key, so both transports honor one opt-out switch.
    private func isTelemetryEnabled() -> Bool {
        (defaults.object(forKey: TelemetryDeckTransport.telemetryEnabledKey) as? Bool) ?? true
    }
}
