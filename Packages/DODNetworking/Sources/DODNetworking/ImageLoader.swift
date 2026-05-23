import Foundation

/// Image-bytes loader with in-flight request coalescing. Two concurrent
/// callers asking for the same URL share a single network request.
///
/// Disk caching is intentionally *not* in this actor — the disk-cache layer
/// belongs to DODPersistence (T-073). This loader speaks bytes only.
///
/// Spec trace: plan §3, supports AC-1.3 (feed images) and AC-5.2 (offline
/// pre-download for saved recipes).
public actor ImageLoader {

    private let httpClient: HTTPClient
    private var inFlight: [URL: Task<Data, Error>] = [:]

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Fetch bytes for an image URL. Concurrent calls for the same URL
    /// share a single Task.
    public func data(for url: URL) async throws -> Data {
        if let existing = inFlight[url] {
            return try await existing.value
        }
        let task = Task<Data, Error> { [httpClient] in
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.httpMethod = "GET"
            let (data, response) = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                throw WPClientError.httpStatus(response.statusCode)
            }
            return data
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }

    /// Test/diagnostic introspection.
    public var inFlightCount: Int { inFlight.count }
}
