import DODDomain
import Foundation

/// WordPress REST API client. Endpoints land in T-051..T-054.
public struct WPRestClient: Sendable {

    public static let defaultBaseURL =
        URL(string: "https://www.dutchovendaddy.com/wp-json/wp/v2/")
        ?? URL(filePath: "/")

    /// Default page size for paginated list endpoints (CL-2).
    public static let defaultPageSize = 20

    /// Wider page size used only by the SEARCH path (CL-120 / T-642 /
    /// REG-29). The list endpoints stay on the 20-row default because
    /// the user scrolls them; the search candidate pool needs to be
    /// wide enough that the post-fetch title-precision filter sees
    /// every title-bearing match WP's relevance ranker might bury
    /// past the 20th slot. WP REST caps `per_page` at 100, so this
    /// is the maximal single-page widening; no pagination bump
    /// required to close the Nacho-Bug class of failures.
    public static let searchPageSize = 100

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
        try await getPaged(path: path, queryItems: queryItems, decode: decode).value
    }

    /// Like ``get(path:queryItems:decode:)`` but also surfaces WP's
    /// `X-WP-TotalPages` response header (DUT-237). Paging callers (Feed,
    /// Categories) use it to stop at the *real* last page instead of guessing
    /// from a short page — a page can return fewer than `per_page` items for
    /// reasons other than the end, which falsely latched the feed's
    /// "reached end" gate. Defaults to 1 page when the header is absent.
    func getPaged<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        decode: T.Type = T.self
    ) async throws -> (value: T, totalPages: Int) {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        // DUT-578: no manual `Accept-Encoding: gzip`. URLSession requests gzip by
        // default and only performs TRANSPARENT response decompression when it
        // owns that header; setting it ourselves would make the caller responsible
        // for gunzipping the `Content-Encoding: gzip` body — and there is no
        // gunzip/inflate anywhere in this module. Let URLSession negotiate + decode.
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
        let totalPages = Self.parseTotalPages(response)
        do {
            return (try decoder.decode(T.self, from: data), totalPages)
        } catch {
            throw WPClientError.decoding(message: String(describing: error))
        }
    }

    /// Parse WP's `X-WP-TotalPages` header, defaulting to 1 when absent,
    /// unparseable, or non-positive (DUT-237, DUT-397 — a present `"0"` must
    /// still clamp to 1 to honor the documented "at least one page" contract).
    static func parseTotalPages(_ response: HTTPURLResponse) -> Int {
        guard let raw = response.value(forHTTPHeaderField: "X-WP-TotalPages"),
            let pages = Int(raw), pages >= 1
        else {
            return 1
        }
        return pages
    }

    /// DUT-386: `.urlQueryAllowed` minus "+" and ";". `URLComponents.queryItems`
    /// leaves both raw, and WordPress/PHP then mis-reads "+" as a space (and ";"
    /// as a query delimiter), silently corrupting a user's search term.
    ///
    /// DUT-438: also minus "&" and "=" — `.urlQueryAllowed` contains BOTH raw
    /// query delimiters, and values assigned via `percentEncodedQueryItems` are
    /// used verbatim, so a search for "mac & cheese" went over the wire as
    /// `?search=mac%20&%20cheese`: the server received `search = "mac "` plus a
    /// bogus `%20cheese` parameter, silently wrecking the results.
    static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+;&=")
        return set
    }()

    func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let resolved = baseURL.appending(path: path)
        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            throw WPClientError.underlying(message: "Bad base URL")
        }
        if !queryItems.isEmpty {
            // DUT-386: encode values ourselves so "+"/";" don't survive raw.
            components.percentEncodedQueryItems = queryItems.map { item in
                URLQueryItem(
                    name: item.name,
                    value: item.value?
                        .addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed)
                )
            }
        }
        guard let url = components.url else {
            throw WPClientError.underlying(message: "Bad URL components")
        }
        return url
    }
}
