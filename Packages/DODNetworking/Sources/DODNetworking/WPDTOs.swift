import DODDomain
import DODSupport
import Foundation

/// Wire-format Data Transfer Objects for the WP REST API. Kept internal to
/// this module; nothing else should see the raw shape.
enum WPDTO {

    /// `/wp/v2/posts` response item (with `_fields` requested in T-051).
    struct Post: Decodable {
        let id: Int
        let slug: String
        let link: URL
        let title: RenderedString
        let excerpt: RenderedString
        let date: String?  // ISO8601 in default WP install
        let featuredMedia: Int?
        let categories: [Int]?

        enum CodingKeys: String, CodingKey {
            case id, slug, link, title, excerpt, date, categories
            case featuredMedia = "featured_media"
        }
    }

    /// WP REST often wraps strings as `{ "rendered": "<p>foo</p>", "protected": false }`.
    struct RenderedString: Decodable {
        let rendered: String
    }

    /// `/wp/v2/categories` response item.
    struct Category: Decodable {
        let id: Int
        let name: String
        let slug: String
        let count: Int
    }

    /// `/wp/v2/media/{id}` — only the fields we use.
    struct Media: Decodable {
        let sourceURL: URL?
        let mediaDetails: MediaDetails?

        enum CodingKeys: String, CodingKey {
            case sourceURL = "source_url"
            case mediaDetails = "media_details"
        }
    }

    struct MediaDetails: Decodable {
        let sizes: [String: MediaSize]?
    }

    struct MediaSize: Decodable {
        let sourceURL: URL?
        let width: Int?
        let height: Int?

        enum CodingKeys: String, CodingKey {
            case sourceURL = "source_url"
            case width, height
        }
    }

    /// WP `date` field is ISO8601 without a timezone, e.g. "2026-05-23T08:00:00".
    /// We assume UTC since the API normalizes server time.
    static func parseWPDate(_ raw: String?) -> Date {
        guard let raw else { return Date() }
        let withZone = raw.hasSuffix("Z") ? raw : raw + "Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: withZone) ?? Date()
    }
}

// MARK: - Domain mapping

extension WPDTO.Post {
    /// Map to a `RecipeListItem` for list screens. Hero image URL is filled
    /// in later by the view-model (it requires a follow-up `/media/{id}` call
    /// or use of the featured media link if pre-resolved).
    func toRecipeListItem(heroImage: URL?) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: HTMLSanitizer.plainText(from: title.rendered),
            excerpt: HTMLSanitizer.plainText(from: excerpt.rendered),
            heroImage: heroImage,
            publishedAt: WPDTO.parseWPDate(date),
            totalTimeDisplay: nil,
            canonicalURL: link
        )
    }
}

extension WPDTO.Category {
    func toDomain() -> DODDomain.Category {
        DODDomain.Category(id: id, name: name, slug: slug, count: count)
    }
}
