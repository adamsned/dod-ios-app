import Foundation

/// In-memory HTTP client for tests. Match incoming requests by URL substring
/// and return canned `(Data, HTTPURLResponse)` pairs. Each request also
/// appears in ``capturedRequests`` for assertion.
///
/// Implemented as an `actor` so it works under Swift 6 strict concurrency
/// (`NSLock` is no longer usable across `await` boundaries).
public actor FakeHTTPClient: HTTPClient {

    public typealias Handler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private var routes: [(matcher: @Sendable (URLRequest) -> Bool, handler: Handler)] = []
    private var _captured: [URLRequest] = []

    public init() {}

    public var capturedRequests: [URLRequest] { _captured }

    /// Register a route matched by URL substring.
    public func stub(urlContaining needle: String, with handler: @escaping Handler) {
        routes.append(
            (
                matcher: { request in
                    request.url?.absoluteString.contains(needle) ?? false
                },
                handler: handler
            )
        )
    }

    /// Shortcut: respond with JSON Data + 200 OK.
    public func stub(urlContaining needle: String, json data: Data, statusCode: Int = 200) {
        stub(urlContaining: needle) { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Failed to synthesize response")
            }
            return (data, response)
        }
    }

    /// Shortcut: respond with text/html body + 200 OK.
    public func stub(urlContaining needle: String, html: String, statusCode: Int = 200) {
        stub(urlContaining: needle) { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=UTF-8"]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Failed to synthesize response")
            }
            return (Data(html.utf8), response)
        }
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        _captured.append(request)
        guard let matched = routes.first(where: { $0.matcher(request) }) else {
            throw WPClientError.underlying(message: "No stub for \(request.url?.absoluteString ?? "<nil>")")
        }
        return try await matched.handler(request)
    }
}
