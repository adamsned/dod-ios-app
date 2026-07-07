import Foundation
import Testing

@testable import DODAnalytics

/// DUT-680: the GA4 Measurement Protocol transport mirrors in-app content
/// OPENS (recipe/article detail views) into Google Analytics 4 — and ONLY
/// those events, only when configured, only when the user hasn't opted out.
/// These L1 tests pin the four contracts (no-op unset, correct request shape,
/// non-open ignored, opt-out silent) through an injected `post` sink so no
/// real network is touched.
@Suite("GA4Transport (DUT-680)") struct GA4TransportTests {

    /// Records the requests the transport would POST, so tests assert on the
    /// exact URL + JSON body without hitting the network.
    final class PostSpy: @unchecked Sendable {
        let lock = NSLock()
        private var _requests: [URLRequest] = []
        func record(_ request: URLRequest) {
            lock.lock()
            defer { lock.unlock() }
            _requests.append(request)
        }
        var requests: [URLRequest] {
            lock.lock()
            defer { lock.unlock() }
            return _requests
        }
    }

    private static func isolatedDefaults(enabled: Bool? = nil) -> UserDefaults {
        let suiteName = "GA4TransportTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        if let enabled { defaults.set(enabled, forKey: TelemetryDeckTransport.telemetryEnabledKey) }
        return defaults
    }

    private static func makeTransport(
        measurementID: String? = "G-TEST123",
        apiSecret: String? = "secret-xyz",
        clientID: String = "client-pseudonym",
        enabled: Bool? = nil,
        spy: PostSpy
    ) -> GA4Transport {
        GA4Transport(
            defaults: isolatedDefaults(enabled: enabled),
            measurementID: measurementID,
            apiSecret: apiSecret,
            clientID: clientID,
            post: { spy.record($0) }
        )
    }

    private static func bodyJSON(_ request: URLRequest) -> [String: Any]? {
        guard let data = request.httpBody,
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    // MARK: - (a) no-op when creds are unset

    @Test func noOpWhenMeasurementIDMissing() {
        let spy = PostSpy()
        let transport = Self.makeTransport(measurementID: nil, spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.isEmpty)
    }

    @Test func noOpWhenAPISecretEmpty() {
        let spy = PostSpy()
        let transport = Self.makeTransport(apiSecret: "", spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.isEmpty)
    }

    @Test func noOpWhenBothCredsBlank() {
        let spy = PostSpy()
        let transport = Self.makeTransport(measurementID: "", apiSecret: "", spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.isEmpty)
    }

    // MARK: - (b) correct /mp/collect URL + JSON body for a recipe-open

    @Test func recipeOpenBuildsCorrectCollectRequest() throws {
        let spy = PostSpy()
        let transport = Self.makeTransport(
            measurementID: "G-TEST123",
            apiSecret: "secret-xyz",
            clientID: "client-pseudonym",
            spy: spy
        )
        transport.send(.recipeView(recipeID: 42))

        let request = try #require(spy.requests.first)
        #expect(spy.requests.count == 1)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // URL: /mp/collect with measurement_id + api_secret query items.
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "www.google-analytics.com")
        #expect(components.path == "/mp/collect")
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        #expect(items["measurement_id"] == "G-TEST123")
        #expect(items["api_secret"] == "secret-xyz")

        // Body: { client_id, events: [{ name: "recipe_open", params: {...} }] }
        let body = try #require(Self.bodyJSON(request))
        #expect(body["client_id"] as? String == "client-pseudonym")
        let events = try #require(body["events"] as? [[String: Any]])
        #expect(events.count == 1)
        #expect(events[0]["name"] as? String == "recipe_open")
        let params = try #require(events[0]["params"] as? [String: String])
        #expect(params["post_id"] == "42")
        // Canonical URL host/path — no PII, no user input.
        #expect(params["page_host"] == "dutchovendaddy.com")
        #expect(params["page_path"] == "/recipe/42")
        // No key carries a raw device identifier or free text.
        for value in params.values { #expect(!value.contains(" ")) }
    }

    @Test func offlineReadAlsoMapsToRecipeOpen() throws {
        let spy = PostSpy()
        let transport = Self.makeTransport(spy: spy)
        transport.send(.offlineRead(recipeID: 7))

        let request = try #require(spy.requests.first)
        let body = try #require(Self.bodyJSON(request))
        let events = try #require(body["events"] as? [[String: Any]])
        #expect(events[0]["name"] as? String == "recipe_open")
        let params = try #require(events[0]["params"] as? [String: String])
        #expect(params["post_id"] == "7")
    }

    // MARK: - (c) non-open events are ignored

    @Test func nonOpenEventsAreIgnored() {
        let spy = PostSpy()
        let transport = Self.makeTransport(spy: spy)
        // A representative sweep of non-content-open events.
        transport.send(.appOpen)
        transport.send(.screenView(name: "feed"))
        transport.send(.recipeSaved(recipeID: 1))
        transport.send(.recipeUnsaved(recipeID: 1))
        transport.send(.recipeSearched(queryHash: "abc"))
        transport.send(.recipeShared(recipeID: 1))
        transport.send(.cookModeStarted(recipeID: 1))
        transport.send(.recipeRated(recipeID: 1, stars: 5))
        transport.send(.widgetOpened(kind: .featured, recipeID: 1))
        transport.send(.syncEnabled)
        #expect(spy.requests.isEmpty)
    }

    // MARK: - (d) opt-out sends nothing

    @Test func optedOutSendsNothing() {
        let spy = PostSpy()
        let transport = Self.makeTransport(enabled: false, spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.isEmpty)
    }

    @Test func optedInSendsContentOpen() {
        let spy = PostSpy()
        let transport = Self.makeTransport(enabled: true, spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.count == 1)
    }

    @Test func absentToggleDefaultsToEnabled() {
        // Constitution §9: telemetry on by default; an absent key still sends.
        let spy = PostSpy()
        let transport = Self.makeTransport(enabled: nil, spy: spy)
        transport.send(.recipeView(recipeID: 42))
        #expect(spy.requests.count == 1)
    }

    // MARK: - pure request builder + pseudonym

    @Test func ga4EventMapsOnlyContentOpens() {
        #expect(GA4Transport.ga4Event(for: .recipeView(recipeID: 3))?.name == "recipe_open")
        #expect(GA4Transport.ga4Event(for: .offlineRead(recipeID: 3))?.name == "recipe_open")
        #expect(GA4Transport.ga4Event(for: .appOpen) == nil)
        #expect(GA4Transport.ga4Event(for: .recipeSaved(recipeID: 3)) == nil)
    }

    @Test func pseudonymIsSaltedAndStable() {
        // Same input -> same pseudonym (stable across runs for distinct-user
        // counts); reuses DUT-669's salt so it isn't an unsalted device-id hash.
        let first = GA4Transport.saltedPseudonym("vendor-uuid-1")
        let firstAgain = GA4Transport.saltedPseudonym("vendor-uuid-1")
        let other = GA4Transport.saltedPseudonym("vendor-uuid-2")
        #expect(first == firstAgain)
        #expect(first != other)
        // SHA-256 hex is 64 chars, and the raw id never appears in the output.
        #expect(first.count == 64)
        #expect(!first.contains("vendor-uuid-1"))
    }
}
