import DODDomain
import Foundation

/// WordPress REST API client. Endpoints land in T-051..T-054.
public struct WPRestClient: Sendable {

    public static let defaultBaseURL =
        URL(string: "https://www.dutchovendaddy.com/wp-json/wp/v2/")
        ?? URL(filePath: "/")

    /// Default page size for paginated list endpoints (CL-2).
    public static let defaultPageSize = 20

    let baseURL: URL
    let httpClient: HTTPClient
    let decoder: JSONDecoder

    public init(baseURL: URL = WPRestClient.defaultBaseURL, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Internal helpers

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        decode: T.Type = T.self
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        // REG-18 (CL-50): bypass URLCache.shared AND Cloudflare's edge CDN so
        // pull-to-refresh actually picks up newly-published recipes. WP REST
        // responses lack a `Cache-Control` header but carry `Last-Modified`,
        // which makes `URLSession.shared` apply HTTP heuristic freshness
        // (~0.1 * (now - Last-Modified)) and serve stale cached payloads on
        // repeated refresh. Cloudflare adds a second stale layer with a
        // multi-minute edge TTL on `cf-cache-status: HIT` responses, so the
        // CDN can return pre-publish JSON even when URLCache misses. Both
        // markers are required: `.reloadIgnoringLocalCacheData` skips the
        // device cache; `Cache-Control: no-cache` asks the CDN to revalidate
        // with origin per RFC 7234 §5.2.1.4.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WPClientError.decoding(message: String(describing: error))
        }
    }

    func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let resolved = baseURL.appending(path: path)
        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            throw WPClientError.underlying(message: "Bad base URL")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw WPClientError.underlying(message: "Bad URL components")
        }
        return url
    }
}
