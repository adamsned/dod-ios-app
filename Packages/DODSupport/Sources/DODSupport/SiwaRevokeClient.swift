import Foundation

/// Configuration for the **Sign in with Apple revoke Worker** (DUT-98 / T-797):
/// the deployed Cloudflare Worker's base URL + the shared `X-DOD-App-Key`. The
/// owner fills ``production`` in after `wrangler deploy` (see
/// `backend/siwa-revoke/README.md`). Until then ``isConfigured`` is `false`, so
/// the app degrades gracefully — no exchange/revoke calls — and Sign in with
/// Apple still works for TestFlight without the Worker.
public struct SiwaRevokeConfig: Sendable {

    public let baseURLString: String
    public let appKey: String

    public init(baseURLString: String, appKey: String) {
        self.baseURLString = baseURLString
        self.appKey = appKey
    }

    /// Replace both fields after deploying the Worker. The placeholders are
    /// sentinels — ``isConfigured`` stays `false` while they're present.
    public static let production = SiwaRevokeConfig(
        baseURLString: "REPLACE_WITH_WORKER_URL",
        appKey: "REPLACE_WITH_APP_SHARED_SECRET"
    )

    /// `true` only once a real `https` Worker URL + a real app key are set.
    public var isConfigured: Bool {
        baseURLString.hasPrefix("https://") && !appKey.hasPrefix("REPLACE")
    }
}

/// Failure modes for the revoke client. `notConfigured` is the expected
/// pre-deploy state and is treated as a non-fatal skip by callers.
public enum SiwaRevokeError: Error, Equatable {
    case notConfigured
    case badURL
    case http(Int)
    case missingRefreshToken
}

/// Talks to the SiwA revoke Worker: `exchange` a one-time authorization code
/// for a long-lived refresh token at sign-in; `revoke` that token on account
/// deletion (App Store 5.1.1(v)). Injectable transport so the L1 suite drives
/// it without the network.
public protocol SiwaRevoking: Sendable {
    /// Exchange the `ASAuthorizationAppleIDCredential.authorizationCode` for a
    /// refresh token (via the Worker → Apple `/auth/token`).
    func exchange(authorizationCode: String) async throws -> String
    /// Revoke the refresh token (via the Worker → Apple `/auth/revoke`).
    func revoke(refreshToken: String) async throws
}

public struct SiwaRevokeClient: SiwaRevoking {

    /// Seam over `URLSession` so tests inject canned `(body, statusCode)`.
    public typealias Transport = @Sendable (_ request: URLRequest) async throws -> (Data, Int)

    let config: SiwaRevokeConfig
    let transport: Transport

    public init(
        config: SiwaRevokeConfig,
        transport: @escaping Transport = SiwaRevokeClient.urlSessionTransport
    ) {
        self.config = config
        self.transport = transport
    }

    public func exchange(authorizationCode: String) async throws -> String {
        let data = try await post(path: "/exchange", json: ["code": authorizationCode])
        struct Response: Decodable { let refreshToken: String? }
        guard let token = (try? JSONDecoder().decode(Response.self, from: data))?.refreshToken,
            !token.isEmpty
        else {
            throw SiwaRevokeError.missingRefreshToken
        }
        return token
    }

    public func revoke(refreshToken: String) async throws {
        _ = try await post(path: "/revoke", json: ["refreshToken": refreshToken])
    }

    private func post(path: String, json: [String: String]) async throws -> Data {
        guard config.isConfigured else { throw SiwaRevokeError.notConfigured }
        guard let url = URL(string: config.baseURLString + path) else {
            throw SiwaRevokeError.badURL
        }
        var request = URLRequest(url: url)
        // DUT-523: this exchange/revoke runs on the Delete Account path
        // (5.1.1(v)). Cap the per-request idle timeout so a stalled Worker
        // can't hang the deletion UI indefinitely.
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.appKey, forHTTPHeaderField: "X-DOD-App-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, status) = try await transport(request)
        guard (200..<300).contains(status) else { throw SiwaRevokeError.http(status) }
        return data
    }

    /// Production transport — a POST over ``hardenedSession``.
    public static let urlSessionTransport: Transport = { request in
        let (data, response) = try await hardenedSession.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// DUT-523: don't use `URLSession.shared` for the Delete Account
    /// exchange/revoke. Mirroring the DUT-519 hardening on
    /// `URLSessionHTTPClient` in DODNetworking — but inlined here because
    /// DODSupport doesn't depend on that module — cap the whole transfer at
    /// 30s (`timeoutIntervalForResource`) and disable connectivity-waiting
    /// (`waitsForConnectivity = false`) so an offline device fails fast during
    /// account deletion instead of parking the request. The per-request
    /// `timeoutInterval: 30` (request-idle timeout, set in `post`) is separate.
    static let hardenedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
}
