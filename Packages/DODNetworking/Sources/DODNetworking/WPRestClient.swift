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
