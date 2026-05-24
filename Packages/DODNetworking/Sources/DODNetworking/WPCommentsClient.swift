import DODDomain
import DODSupport
import Foundation

/// Reads and writes WordPress comments for a recipe post.
///
/// Spec trace: spec.md US-13 (read comments on a recipe) + REG-13 (the
/// comments contract: approved comments round-trip body, author name,
/// avatar, GMT date, and optional WPRM star rating, with pagination
/// surfacing the `X-WP-Total*` headers).
public struct WPCommentsClient: Sendable {

    /// Same WP base used by ``WPRestClient`` so the two clients can share an
    /// origin in production and a stub in tests.
    public static let defaultBaseURL =
        URL(string: "https://www.dutchovendaddy.com/wp-json/wp/v2/")
        ?? URL(filePath: "/")

    let baseURL: URL
    let httpClient: HTTPClient
    let decoder: JSONDecoder

    public init(
        baseURL: URL = WPCommentsClient.defaultBaseURL,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Public surface

    /// One page of comments for a recipe, newest first.
    ///
    /// Uses `_embed=author` so avatar URLs come back in a single round trip
    /// and we don't have to chase per-author `/users/{id}` calls.
    ///
    /// - Parameters:
    ///   - postID: WP post ID for the recipe.
    ///   - page: 1-based page index.
    ///   - perPage: page size; capped at 100 by WP.
    public func comments(
        forPostID postID: Int,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> CommentsPage {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "post", value: String(postID)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "_embed", value: "author"),
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
        ]
        let url = try buildURL(path: "comments", queryItems: queryItems)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        let dtos: [WPDTO.Comment]
        do {
            dtos = try decoder.decode([WPDTO.Comment].self, from: data)
        } catch {
            throw WPClientError.decoding(message: String(describing: error))
        }
        return CommentsPage(
            comments: dtos.map { $0.toDomain() },
            totalPages: Self.parseHeader(response, key: "X-WP-TotalPages") ?? 1,
            totalCount: Self.parseHeader(response, key: "X-WP-Total") ?? dtos.count
        )
    }

    /// Submit a new comment for moderation.
    ///
    /// WP routes new comments through the moderation queue by default, so
    /// the returned comment usually has `status == .hold` until an admin
    /// approves it. View layer should reflect that pending state.
    ///
    /// - Parameter ratingValue: When non-nil, sent as
    ///   `meta.wprm_comment_rating` so WPRM credits the comment with a star
    ///   rating. Out-of-range values (≤0 or >5) throw
    ///   ``WPClientError/underlying(message:)``.
    public func postComment(
        postID: Int,
        authorName: String,
        authorEmail: String,
        content: String,
        ratingValue: Int? = nil
    ) async throws -> RecipeComment {
        if let ratingValue, !(1...5).contains(ratingValue) {
            throw WPClientError.underlying(message: "ratingValue must be 1...5; got \(ratingValue)")
        }
        let url = try buildURL(path: "comments", queryItems: [])
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = try Self.encodePostBody(
            postID: postID,
            authorName: authorName,
            authorEmail: authorEmail,
            content: content,
            ratingValue: ratingValue
        )

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        do {
            let dto = try decoder.decode(WPDTO.Comment.self, from: data)
            return dto.toDomain()
        } catch {
            throw WPClientError.decoding(message: String(describing: error))
        }
    }

    // MARK: - Result types

    /// A single page of comments plus the pagination counts WP returns in
    /// `X-WP-Total` and `X-WP-TotalPages`. Used by the detail view's "load
    /// more" affordance.
    public struct CommentsPage: Sendable, Hashable {
        public let comments: [RecipeComment]
        public let totalPages: Int
        public let totalCount: Int

        public init(comments: [RecipeComment], totalPages: Int, totalCount: Int) {
            self.comments = comments
            self.totalPages = totalPages
            self.totalCount = totalCount
        }
    }

    // MARK: - Internals

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

    static func encodePostBody(
        postID: Int,
        authorName: String,
        authorEmail: String,
        content: String,
        ratingValue: Int?
    ) throws -> Data {
        var payload: [String: Any] = [
            "post": postID,
            "author_name": authorName,
            "author_email": authorEmail,
            "content": content,
        ]
        if let ratingValue {
            payload["meta"] = ["wprm_comment_rating": ratingValue]
        }
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        } catch {
            throw WPClientError.underlying(message: "Failed to encode comment body: \(error)")
        }
    }

    static func parseHeader(_ response: HTTPURLResponse, key: String) -> Int? {
        // Case-insensitive lookup — HTTP/2 lowercases header names.
        let value =
            response.value(forHTTPHeaderField: key)
            ?? response.value(forHTTPHeaderField: key.lowercased())
        guard let value else { return nil }
        return Int(value)
    }
}
