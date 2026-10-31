import Foundation

/// One release's notes, as authored in WP (DUT-174).
public struct ChangelogRelease: Codable, Sendable, Hashable, Identifiable {
    public let version: String  // marketing version, e.g. "2.1"
    public let title: String
    public let bullets: [String]  // 3-5 friendly highlights
    public let heroImageURL: URL?

    public var id: String { version }

    public init(
        version: String,
        title: String,
        bullets: [String],
        heroImageURL: URL? = nil
    ) {
        self.version = version
        self.title = title
        self.bullets = bullets
        self.heroImageURL = heroImageURL
    }

    enum CodingKeys: String, CodingKey {
        case version, title, bullets
        case heroImageURL = "hero_image_url"
    }
}

/// Fetches the versioned changelog collection from WP REST.
///
/// Contract: the WP side must serve `GET dod/v1/changelog` returning a JSON
/// array of releases (`version`, `title`, `bullets`, optional `hero_image_url`),
/// newest first.
public struct WPChangelogClient: Sendable {
    public static let defaultBaseURL =
        URL(string: "https://www.dutchovendaddy.com/wp-json/dod/v1/")
        ?? URL(filePath: "/")

    let baseURL: URL
    let httpClient: HTTPClient

    public init(
        baseURL: URL = WPChangelogClient.defaultBaseURL,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
    }

    /// GET `<base>changelog` -> JSON array of ``ChangelogRelease``, newest-first as served.
    public func releases() async throws -> [ChangelogRelease] {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("changelog"),
            timeoutInterval: 30
        )
        request.httpMethod = "GET"
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        return try JSONDecoder().decode([ChangelogRelease].self, from: data)
    }
}
