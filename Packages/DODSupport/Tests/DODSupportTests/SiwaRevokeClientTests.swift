import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``SiwaRevokeClient`` (DUT-98 / T-797) — the iOS side of the
/// Sign in with Apple token exchange + revoke. Drives an injected transport so
/// no network is touched; asserts the request shape (path, auth header, body)
/// and the response handling.
@Suite("SiwaRevokeClient (DUT-98)")
struct SiwaRevokeClientTests {

    private static let liveConfig = SiwaRevokeConfig(
        baseURLString: "https://dod-siwa-revoke.example.workers.dev",
        appKey: "test-shared-secret"
    )

    /// Capture the last request + return a canned `(body, status)`.
    private final class Recorder: @unchecked Sendable {
        var lastRequest: URLRequest?
        var body: Data
        var status: Int
        init(body: Data = Data(), status: Int = 200) {
            self.body = body
            self.status = status
        }
        var transport: SiwaRevokeClient.Transport {
            { [self] request in
                lastRequest = request
                return (body, status)
            }
        }
    }

    @Test func exchangeReturnsRefreshTokenAndSendsAuthHeader() async throws {
        let rec = Recorder(body: Data(#"{"refreshToken":"rt-abc-123"}"#.utf8), status: 200)
        let client = SiwaRevokeClient(config: Self.liveConfig, transport: rec.transport)

        let token = try await client.exchange(authorizationCode: "auth-code-xyz")
        #expect(token == "rt-abc-123")

        let request = try #require(rec.lastRequest)
        #expect(request.url?.absoluteString == "https://dod-siwa-revoke.example.workers.dev/exchange")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-DOD-App-Key") == "test-shared-secret")
        let sent = request.httpBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: String]
        }
        #expect(sent?["code"] == "auth-code-xyz")
    }

    @Test func exchangeThrowsWhenRefreshTokenMissing() async {
        let rec = Recorder(body: Data(#"{"error":"exchange_failed"}"#.utf8), status: 200)
        let client = SiwaRevokeClient(config: Self.liveConfig, transport: rec.transport)
        await #expect(throws: SiwaRevokeError.missingRefreshToken) {
            _ = try await client.exchange(authorizationCode: "x")
        }
    }

    @Test func revokePostsTheTokenToTheRevokeEndpoint() async throws {
        let rec = Recorder(body: Data(#"{"revoked":true}"#.utf8), status: 200)
        let client = SiwaRevokeClient(config: Self.liveConfig, transport: rec.transport)

        try await client.revoke(refreshToken: "rt-abc-123")

        let request = try #require(rec.lastRequest)
        #expect(request.url?.absoluteString.hasSuffix("/revoke") == true)
        let sent = request.httpBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: String]
        }
        #expect(sent?["refreshToken"] == "rt-abc-123")
    }

    @Test func nonSuccessStatusThrowsHTTP() async {
        let rec = Recorder(body: Data(), status: 502)
        let client = SiwaRevokeClient(config: Self.liveConfig, transport: rec.transport)
        await #expect(throws: SiwaRevokeError.http(502)) {
            try await client.revoke(refreshToken: "rt")
        }
    }

    @Test func placeholderConfigIsNotConfiguredAndSkips() async {
        // The pre-deploy default must not fire a network call — callers treat
        // `.notConfigured` as a graceful skip so SiwA still works pre-Worker.
        #expect(SiwaRevokeConfig.production.isConfigured == false)
        let client = SiwaRevokeClient(config: .production) { _ in
            Issue.record("transport must not be called when not configured")
            return (Data(), 200)
        }
        await #expect(throws: SiwaRevokeError.notConfigured) {
            try await client.revoke(refreshToken: "rt")
        }
    }

    @Test func liveConfigIsConfigured() {
        #expect(Self.liveConfig.isConfigured)
    }

    /// DUT-523: the exchange/revoke request (Delete Account, 5.1.1(v)) must
    /// carry a bounded per-request timeout so a stalled Worker can't hang the
    /// deletion UI indefinitely.
    @Test func requestCarriesThirtySecondTimeout() async throws {
        let rec = Recorder(body: Data(#"{"revoked":true}"#.utf8), status: 200)
        let client = SiwaRevokeClient(config: Self.liveConfig, transport: rec.transport)
        try await client.revoke(refreshToken: "rt-abc-123")
        let request = try #require(rec.lastRequest)
        #expect(request.timeoutInterval == 30)
    }
}
