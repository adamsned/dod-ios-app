import Foundation
import Testing

@testable import DODNetworking

/// REG-27 / US-14 (round-9 backlog hypothesis H3): `URLSessionHTTPClient`
/// stamps a recognizable `User-Agent` header on every outgoing request so
/// WordPress security plugins (Wordfence et al.) don't 403 the comment-POST
/// path with an empty-UA reject. The default value is constructed from
/// `Bundle.main`'s short version + build + bundle identifier; SPM test
/// bundles fall back to a static-but-recognizable string.
///
/// Spec trace: REG-27 in `spec.md`; CL-108 in `clarifications.md`.
@Suite("URLSessionHTTPClient (REG-27 / US-14)", .serialized)
struct URLSessionHTTPClientTests {

    @Test func stampsDefaultUserAgentWhenCallerSetsNone() async throws {
        RecordingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session, userAgent: "DODApp-Test/1.0 (iOS; test)")

        let url = try #require(URL(string: "https://www.dutchovendaddy.com/wp-json/wp/v2/comments"))
        let request = URLRequest(url: url)
        _ = try? await client.data(for: request)

        let recorded = RecordingURLProtocol.lastRequest()
        let ua = try #require(recorded?.value(forHTTPHeaderField: "User-Agent"))
        #expect(ua == "DODApp-Test/1.0 (iOS; test)")
    }

    @Test func doesNotOverwriteCallerSuppliedUserAgent() async throws {
        RecordingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session, userAgent: "DODApp-Default/1.0")

        let url = try #require(URL(string: "https://example.com/"))
        var request = URLRequest(url: url)
        request.setValue("CustomAgent/1.0", forHTTPHeaderField: "User-Agent")
        _ = try? await client.data(for: request)

        let recorded = RecordingURLProtocol.lastRequest()
        let ua = try #require(recorded?.value(forHTTPHeaderField: "User-Agent"))
        #expect(ua == "CustomAgent/1.0")
    }

    @Test func defaultUserAgentReturnsNonEmptyDODAppString() {
        let ua = URLSessionHTTPClient.defaultUserAgent()
        #expect(ua.hasPrefix("DODApp/"))
        #expect(ua.contains("iOS") || ua.contains("macOS") || ua.contains("unknown"))
        #expect(ua.contains("("))
    }

    /// DUT-519 — the default production session must cap the whole transfer so
    /// a slow/trickling body can't hang the `await` for the 7-day
    /// `URLSession.shared` default. Offline requests fail fast rather than
    /// parking on connectivity.
    @Test func hardenedConfigurationCapsResourceTimeoutAndDisablesConnectivityWait() {
        let configuration = URLSessionHTTPClient.hardenedConfiguration()
        #expect(configuration.timeoutIntervalForResource == 60)
        #expect(configuration.waitsForConnectivity == false)
    }
}

// MARK: - RecordingURLProtocol

/// `URLProtocol` subclass that records the last seen request + returns an
/// empty 200 response so the `URLSession` data task completes cleanly.
/// Lives in this test file because `URLSessionHTTPClient` is the only
/// surface that needs request-capture against a real session today.
final class RecordingURLProtocol: URLProtocol, @unchecked Sendable {

    private static let storage = RequestStorage()

    static func reset() {
        storage.set(nil)
    }

    static func lastRequest() -> URLRequest? {
        storage.get()
    }

    // These override `URLProtocol.class func` declarations and must remain
    // `class func`; SwiftLint's static_over_final_class rule misfires here.
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.storage.set(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Thread-safe storage for the last request — `URLProtocol.startLoading`
    /// can be called on any queue.
    private final class RequestStorage: @unchecked Sendable {
        private var value: URLRequest?
        private let lock = NSLock()
        func set(_ request: URLRequest?) {
            lock.lock()
            defer { lock.unlock() }
            value = request
        }
        func get() -> URLRequest? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }
}
