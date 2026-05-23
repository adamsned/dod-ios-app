import Foundation

/// The single seam between this module and the real `URLSession`. Production
/// uses ``URLSessionHTTPClient``; tests use ``FakeHTTPClient`` and inject a
/// per-request stub.
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Default implementation backed by `URLSession`.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WPClientError.underlying(message: "Non-HTTP response")
            }
            return (data, httpResponse)
        } catch {
            throw WPClientError.wrap(error)
        }
    }
}
