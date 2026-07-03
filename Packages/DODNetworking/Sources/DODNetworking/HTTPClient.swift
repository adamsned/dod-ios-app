import Foundation

/// The single seam between this module and the real `URLSession`. Production
/// uses ``URLSessionHTTPClient``; tests use ``FakeHTTPClient`` and inject a
/// per-request stub.
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Default implementation backed by `URLSession`.
///
/// Every outgoing request gets a ``userAgent`` stamped into its `User-Agent`
/// header (unless the caller already set one). Defensive medicine per
/// REG-27 / round-9 backlog hypothesis H3 — a few WordPress security
/// plugins (Wordfence is the canonical example) rate-limit or 403 requests
/// from clients with an empty / default User-Agent, and a missing UA was
/// one of the five hypotheses for the broken TestFlight 1.0 (2) comment
/// POST. The default value is constructed from `Bundle.main` so production
/// stamps the real `CFBundleShortVersionString` / `CFBundleVersion`, while
/// SPM test bundles (no host app, so the values fall through to a static
/// fallback string) still send something recognizable.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let userAgent: String

    /// Shared production session. DUT-519: `URLSession.shared` leaves
    /// `timeoutIntervalForResource` at its 7-day default, so a slow/trickling
    /// response body hangs the `await` effectively forever. Cap the whole
    /// transfer at 60s and disable connectivity-waiting so an offline device
    /// fails fast instead of parking the request. The per-request
    /// `timeoutInterval: 30` (request-idle timeout) is unaffected.
    public static let sharedSession = URLSession(configuration: hardenedConfiguration())

    /// The `URLSessionConfiguration` behind ``sharedSession``. Factored out so
    /// tests can assert the DUT-519 hardening without exposing a stored
    /// session on the public API.
    static func hardenedConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return configuration
    }

    public init(
        session: URLSession = URLSessionHTTPClient.sharedSession,
        userAgent: String = URLSessionHTTPClient.defaultUserAgent()
    ) {
        self.session = session
        self.userAgent = userAgent
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var stamped = request
        if stamped.value(forHTTPHeaderField: "User-Agent") == nil {
            stamped.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        do {
            let (data, response) = try await session.data(for: stamped)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WPClientError.underlying(message: "Non-HTTP response")
            }
            return (data, httpResponse)
        } catch {
            throw WPClientError.wrap(error)
        }
    }

    /// Build the production User-Agent string from `Bundle.main`'s short
    /// version + build number + bundle identifier. Falls back to a fixed
    /// `DODApp/1.0 (iOS)` string if those keys are unset (SPM test bundles
    /// hosted outside the app — the value is informational, not a contract).
    public static func defaultUserAgent() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let bundleID = info["CFBundleIdentifier"] as? String ?? "com.dutchovendaddy.DODApp"
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif
        return "DODApp/\(shortVersion).\(build) (\(platform); \(bundleID))"
    }
}
