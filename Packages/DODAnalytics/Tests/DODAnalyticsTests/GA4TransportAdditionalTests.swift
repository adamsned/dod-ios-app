import Foundation
import Testing

@testable import DODAnalytics

/// Additional targeted coverage for GA4Transport pure functions and edge cases
/// not covered by GA4TransportTests.swift. These focus on:
/// - sha256Hex determinism and properties
/// - canonicalURLComponents format verification
/// - makeCollectRequest pure function contract
/// - configure(appID:) no-op requirement
@Suite("GA4Transport Additional Coverage") struct GA4TransportAdditionalTests {

    // MARK: - sha256Hex determinism and properties

    @Test func sha256HexIsDeterministic() {
        // Same input produces identical output across multiple calls
        let input = "test-vendor-id-12345"
        let hash1 = GA4Transport.sha256Hex(input)
        let hash2 = GA4Transport.sha256Hex(input)
        let hash3 = GA4Transport.sha256Hex(input)
        #expect(hash1 == hash2)
        #expect(hash2 == hash3)
    }

    @Test func sha256HexProduces64CharHex() {
        // SHA-256 hex digest is exactly 64 characters (256 bits / 4 bits per hex char)
        let result = GA4Transport.sha256Hex("input")
        #expect(result.count == 64)
    }

    @Test func sha256HexIsLowercase() {
        // Output must be lowercase hex for GA4 client_id consistency
        let result = GA4Transport.sha256Hex("SomeCapitalLetters123")
        let isLowercase = result.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
        #expect(isLowercase)
    }

    @Test func sha256HexDoesNotContainInput() {
        // Raw identifier must not appear in the hash output (privacy)
        let input = "raw-vendor-uuid-xyz"
        let hash = GA4Transport.sha256Hex(input)
        #expect(!hash.contains(input))
    }

    @Test func sha256HexDifferentInputsDifferentOutput() {
        // Different inputs produce different hashes
        let hash1 = GA4Transport.sha256Hex("input-one")
        let hash2 = GA4Transport.sha256Hex("input-two")
        #expect(hash1 != hash2)
    }

    @Test func sha256HexEmptyStringProducesHash() {
        // Even empty input produces a valid 64-char hash
        let hash = GA4Transport.sha256Hex("")
        #expect(hash.count == 64)
        #expect(!hash.isEmpty)
    }

    // MARK: - canonicalURLComponents format and stability

    @Test func canonicalURLComponentsReturnsCorrectHost() {
        // Always returns dutchovendaddy.com as the host
        let components = GA4Transport.canonicalURLComponents(recipeID: 42)
        #expect(components?.host == "dutchovendaddy.com")
    }

    @Test func canonicalURLComponentsBuildsRecipePath() {
        // Path is /recipe/<id> format
        let components = GA4Transport.canonicalURLComponents(recipeID: 123)
        #expect(components?.path == "/recipe/123")
    }

    @Test func canonicalURLComponentsNeverReturnsNil() {
        // Function always succeeds; it's deterministic and hardcoded
        let testIDs = [1, 7, 42, 100, 999, 12345, Int.max / 2]
        for id in testIDs {
            let components = GA4Transport.canonicalURLComponents(recipeID: id)
            #expect(components != nil)
        }
    }

    @Test func canonicalURLComponentsPreservesRecipeID() {
        // The recipe ID in the path exactly matches input
        let ids = [1, 999, 54321]
        for id in ids {
            let components = GA4Transport.canonicalURLComponents(recipeID: id)
            #expect(components?.path.contains(String(id)) ?? false)
        }
    }

    // MARK: - makeCollectRequest pure function contract

    @Test func makeCollectRequestBuildCorrectURL() {
        // URL endpoint is https://www.google-analytics.com/mp/collect
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST123",
            apiSecret: "secret-abc",
            clientID: "client-id-xyz",
            event: GA4Transport.GA4Event(name: "recipe_open", params: ["post_id": "42"])
        )
        #expect(request != nil)

        guard let req = request, let url = req.url else {
            #expect(Bool(false), "Request should have valid URL")
            return
        }
        #expect(url.scheme == "https")
        #expect(url.host == "www.google-analytics.com")
        #expect(url.path == "/mp/collect")
    }

    @Test func makeCollectRequestIncludesQueryItems() {
        // URL must have measurement_id and api_secret as query items
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-MEASUREMENT-123",
            apiSecret: "secret-key-xyz",
            clientID: "client-pseudonym",
            event: GA4Transport.GA4Event(name: "recipe_open", params: ["post_id": "7"])
        )
        guard let req = request,
            let url = req.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            #expect(Bool(false), "Should be able to extract query items")
            return
        }

        let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        #expect(queryDict["measurement_id"] == "G-MEASUREMENT-123")
        #expect(queryDict["api_secret"] == "secret-key-xyz")
    }

    @Test func makeCollectRequestSetsPostMethod() {
        // HTTP method must be POST
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST",
            apiSecret: "secret",
            clientID: "client",
            event: GA4Transport.GA4Event(name: "recipe_open", params: ["post_id": "1"])
        )
        #expect(request?.httpMethod == "POST")
    }

    @Test func makeCollectRequestSetsContentTypeHeader() {
        // Content-Type header must be application/json
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST",
            apiSecret: "secret",
            clientID: "client",
            event: GA4Transport.GA4Event(name: "recipe_open", params: ["post_id": "1"])
        )
        #expect(request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func makeCollectRequestBodyHasCorrectStructure() {
        // JSON body must be {client_id: "...", events: [{name: "recipe_open", params: {...}}]}
        let event = GA4Transport.GA4Event(
            name: "recipe_open",
            params: ["post_id": "42", "page_host": "dutchovendaddy.com"]
        )
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST",
            apiSecret: "secret",
            clientID: "test-client-id",
            event: event
        )
        guard let req = request, let bodyData = req.httpBody else {
            #expect(Bool(false), "Request should have body")
            return
        }

        guard let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            #expect(Bool(false), "Body should be valid JSON")
            return
        }

        #expect(bodyJSON["client_id"] as? String == "test-client-id")

        guard let events = bodyJSON["events"] as? [[String: Any]] else {
            #expect(Bool(false), "events should be array")
            return
        }
        #expect(events.count == 1)
        #expect(events[0]["name"] as? String == "recipe_open")

        guard let params = events[0]["params"] as? [String: String] else {
            #expect(Bool(false), "params should be string dict")
            return
        }
        #expect(params["post_id"] == "42")
        #expect(params["page_host"] == "dutchovendaddy.com")
    }

    @Test func makeCollectRequestBodyAlwaysHasEventName() {
        // The event name from GA4Event must appear in the JSON
        let event1 = GA4Transport.GA4Event(name: "recipe_open", params: [:])
        let request1 = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST",
            apiSecret: "secret",
            clientID: "client",
            event: event1
        )
        guard let req1 = request1, let bodyData1 = req1.httpBody,
            let bodyJSON1 = try? JSONSerialization.jsonObject(with: bodyData1) as? [String: Any],
            let events1 = bodyJSON1["events"] as? [[String: Any]]
        else {
            #expect(Bool(false))
            return
        }
        #expect(events1[0]["name"] as? String == "recipe_open")
    }

    @Test func makeCollectRequestWithSpecialCharactersInCreds() {
        // Creds with special characters should be URL-encoded properly
        let request = GA4Transport.makeCollectRequest(
            measurementID: "G-TEST&param=value",
            apiSecret: "secret?with=special&chars",
            clientID: "client-id",
            event: GA4Transport.GA4Event(name: "recipe_open", params: ["post_id": "1"])
        )
        guard let req = request, let url = req.url?.absoluteString else {
            #expect(Bool(false), "Should handle special characters")
            return
        }
        // URL should be properly formatted (encoded or at least parseable)
        #expect(url.contains("measurement_id"))
        #expect(url.contains("api_secret"))
    }

    // MARK: - ga4Event params building

    @Test func ga4EventIncludesPostID() {
        // post_id param is always present for content opens
        let event1 = GA4Transport.ga4Event(for: .recipeView(recipeID: 99))
        #expect(event1?.params["post_id"] == "99")

        let event2 = GA4Transport.ga4Event(for: .offlineRead(recipeID: 42))
        #expect(event2?.params["post_id"] == "42")
    }

    @Test func ga4EventIncludesCanonicalURLParams() {
        // When canonicalURLComponents succeeds, page_host and page_path are included
        let event = GA4Transport.ga4Event(for: .recipeView(recipeID: 123))
        #expect(event?.params["page_host"] != nil)
        #expect(event?.params["page_path"] != nil)
        #expect(event?.params["page_host"] == "dutchovendaddy.com")
        #expect(event?.params["page_path"] == "/recipe/123")
    }

    @Test func ga4EventParamsAreStringOnly() {
        // All params values must be strings (no PII, no complex types)
        let event = GA4Transport.ga4Event(for: .recipeView(recipeID: 42))
        guard let params = event?.params else {
            #expect(Bool(false), "Event should have params")
            return
        }
        #expect(!params.isEmpty, "Event should have params")
        for (key, value) in params {
            // Additional PII check: no spaces in values (they're all structured ids/urls)
            #expect(!value.contains(" "), "Param '\(key)' should not contain spaces (likely PII)")
        }
    }

    // MARK: - configure(appID:) no-op

    @Test func configureIsNoOp() {
        // configure should be a no-op; calling it shouldn't affect behavior
        let spy = PostSpy()
        let transport = GA4Transport(
            defaults: Self.isolatedDefaults(),
            measurementID: "G-TEST",
            apiSecret: "secret",
            clientID: "client",
            post: { spy.record($0) }
        )

        transport.configure(appID: "ignored-app-id")
        transport.send(AnalyticsEvent.recipeView(recipeID: 42))

        // Transport should still work normally after configure
        #expect(spy.requests.count == 1)
    }

    // MARK: - Helpers (reused from GA4TransportTests)

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
        let suiteName = "GA4TransportAdditionalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        if let enabled { defaults.set(enabled, forKey: TelemetryDeckTransport.telemetryEnabledKey) }
        return defaults
    }
}
