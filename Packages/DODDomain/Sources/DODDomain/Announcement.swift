import Foundation

/// A creator-authored "From Ned" post (DUT-147). Read-only, no UGC.
public struct Announcement: Sendable, Hashable, Identifiable {
    public enum DeepLink: Sendable, Hashable {
        case recipe(URL)  // dutchovendaddy.com post
        case shop(URL)  // buzzywaxx.com
        case tipJar  // planned; matched by path containing "tip-jar"

        /// Map a link found in a post to a deep link. nil = not routable in-app.
        public init?(url: URL) {
            let host = (url.host ?? "").lowercased()
            if host.hasSuffix("buzzywaxx.com") {
                self = .shop(url)
            } else if host.hasSuffix("dutchovendaddy.com") {
                self = url.path.lowercased().contains("tip-jar") ? .tipJar : .recipe(url)
            } else {
                return nil
            }
        }
    }

    public let id: Int
    public let title: String
    public let bodyMarkdown: String
    public let imageURL: URL?
    public let publishedAt: Date
    public let deepLink: DeepLink?

    public init(
        id: Int,
        title: String,
        bodyMarkdown: String,
        imageURL: URL? = nil,
        publishedAt: Date,
        deepLink: DeepLink? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.deepLink = deepLink
    }
}
