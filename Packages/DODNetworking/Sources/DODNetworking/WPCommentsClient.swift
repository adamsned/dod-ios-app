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
    /// On a non-2xx the failure is never swallowed: the status is surfaced
    /// as ``WPClientError/httpStatusWithBody(_:message:)`` carrying
    /// WordPress's own error text (a `rest_*` JSON message or a tag-stripped
    /// Wordfence challenge snippet) when the body has one, else the
    /// status-only ``WPClientError/httpStatus(_:)``. Mirrors ``postComment``
    /// so the comments read + write paths diagnose identically (DUT-23 /
    /// DUT-7 — the "Couldn't load comments" report carried no server detail
    /// because this read path previously threw a bare status).
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

        // DUT-23 / DUT-7 parity: log the GET target so the owner can confirm
        // on-device (Console.app, subsystem com.dutchovendaddy.DODApp) which
        // URL the comments LOAD hit. The TestFlight "Couldn't load comments"
        // report (DUT-23) gave us no server detail because this read path —
        // unlike the DUT-7-hardened POST path — emitted no breadcrumb at the
        // client seam. Privacy-safe: URL + post ID only.
        DODLog.network.notice(
            "comment GET → \(url.absoluteString, privacy: .public) (post=\(postID, privacy: .public) page=\(page, privacy: .public))"
        )

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            // DUT-23: the "Couldn't load comments" failure is the read-path
            // twin of DUT-7's swallowed-POST. Surface the status AND
            // WordPress's own error body (Wordfence HTML challenge, a
            // `rest_*` JSON error, etc.) so the on-device log pins *why* the
            // load failed instead of collapsing to a bare code. Mirrors the
            // POST path's `extractWPErrorMessage` → `httpStatusWithBody`
            // fallback exactly so both comment paths read identically.
            let serverMessage = Self.extractWPErrorMessage(from: data)
            DODLog.network.error(
                "comment GET failed status=\(response.statusCode, privacy: .public) post=\(postID, privacy: .public) message=\(serverMessage ?? "<none>", privacy: .public)"
            )
            if let serverMessage {
                throw WPClientError.httpStatusWithBody(response.statusCode, message: serverMessage)
            }
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
        // DUT-7 hypothesis #4, network-layer backstop: WordPress requires a
        // non-empty author name + email for an anonymous (no-auth) comment
        // POST and 400s otherwise. The view model gates on this already, but
        // guard here too so the failure is a typed, descriptive error at the
        // seam — never a silent empty-field 400 — regardless of caller.
        guard !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WPClientError.underlying(message: "author name must not be empty")
        }
        guard !authorEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WPClientError.underlying(message: "author email must not be empty")
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

        // DUT-7 diagnostic breadcrumb: log the POST target so the owner can
        // confirm on-device (Console.app, subsystem com.dutchovendaddy.DODApp)
        // that the request actually reached the wp-json endpoint and which URL
        // it hit. Privacy-safe — URL + post ID only, never the comment body or
        // the author's name/email.
        DODLog.network.notice(
            "comment POST → \(url.absoluteString, privacy: .public) (post=\(postID, privacy: .public))"
        )

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            // DUT-7 hypothesis #1: a swallowed non-2xx is exactly the "tap,
            // nothing happens" report. Surface the status AND WordPress's own
            // error message (it explains *why* — moderation, spam, missing
            // field, blocked UA) so the snackbar and the on-device log both
            // pin the cause instead of collapsing to a bare code.
            let serverMessage = Self.extractWPErrorMessage(from: data)
            DODLog.network.error(
                "comment POST failed status=\(response.statusCode, privacy: .public) message=\(serverMessage ?? "<none>", privacy: .public)"
            )
            if let serverMessage {
                throw WPClientError.httpStatusWithBody(response.statusCode, message: serverMessage)
            }
            throw WPClientError.httpStatus(response.statusCode)
        }
        do {
            let dto = try decoder.decode(WPDTO.Comment.self, from: data)
            DODLog.network.notice(
                "comment POST ok status=\(response.statusCode, privacy: .public) id=\(dto.id, privacy: .public) wpStatus=\(dto.status ?? "<unknown>", privacy: .public)"
            )
            return dto.toDomain()
        } catch {
            DODLog.network.error("comment POST decode failed: \(String(describing: error), privacy: .public)")
            throw WPClientError.decoding(message: String(describing: error))
        }
    }

    /// Pull the human-readable `message` out of a WordPress REST error body.
    /// WP returns rejected writes as `{"code":"...","message":"...",
    /// "data":{"status":NNN}}`; some security plugins (Wordfence) return an
    /// HTML block instead. Returns `nil` when the body has no usable message
    /// so the caller falls back to the status-only ``WPClientError/httpStatus(_:)``.
    /// HTML bodies are reduced to a short tag-stripped snippet so a 403 HTML
    /// challenge page still surfaces *something* the owner can recognize.
    static func extractWPErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        // If the body is a JSON object, trust ONLY its `message` field — a
        // structured WP error with no usable message (e.g. `{}` or a blank
        // string) yields nil rather than dumping the raw JSON at the user.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard let message = object["message"] as? String else { return nil }
            let cleaned = Self.stripHTML(message).trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : String(cleaned.prefix(140))
        }
        // Not a JSON object (e.g. a Wordfence HTML challenge page). Strip
        // tags + clamp so a 403 challenge still surfaces something readable.
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let stripped = Self.stripHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }
        return String(stripped.prefix(140))
    }

    /// Minimal tag stripper — WP `message` fields can contain inline `<code>`
    /// / `<a>` markup, and security-plugin bodies are full HTML pages. Keeps
    /// the snackbar readable without pulling in a full HTML parser.
    static func stripHTML(_ string: String) -> String {
        let withoutTags = string.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        return
            withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
