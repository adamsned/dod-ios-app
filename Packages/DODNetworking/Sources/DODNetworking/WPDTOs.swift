import DODDomain
import DODSupport
import Foundation

/// Wire-format Data Transfer Objects for the WP REST API. Kept internal to
/// this module; nothing else should see the raw shape.
enum WPDTO {

    /// `/wp/v2/posts` response item. With `_embed=wp:featuredmedia`, WP
    /// inlines the resolved image URLs under `_embedded` so we avoid a
    /// per-recipe follow-up call to /media/{id}.
    struct Post: Decodable {
        let id: Int
        let slug: String
        let link: URL
        let title: RenderedString
        let excerpt: RenderedString
        let date: String?
        /// Genuine UTC publish timestamp. `date` is site-local with no offset,
        /// so labeling it as UTC can shift the displayed calendar day (DUT-311);
        /// prefer `dateGMT` for `publishedAt`.
        let dateGMT: String?
        let featuredMedia: Int?
        let categories: [Int]?
        let embedded: PostEmbedded?

        enum CodingKeys: String, CodingKey {
            case id, slug, link, title, excerpt, date, categories
            case dateGMT = "date_gmt"
            case featuredMedia = "featured_media"
            case embedded = "_embedded"
        }

        /// Pick the best size from the embedded media, preferring
        /// medium_large for list rows (CL-6).
        var inlineHeroURL: URL? {
            guard let media = embedded?.featuredMedia?.first else { return nil }
            let sizes = media.mediaDetails?.sizes ?? [:]
            return sizes["medium_large"]?.sourceURL
                ?? sizes["medium"]?.sourceURL
                ?? media.sourceURL
        }
    }

    struct PostEmbedded: Decodable {
        let featuredMedia: [Media]?

        enum CodingKeys: String, CodingKey {
            case featuredMedia = "wp:featuredmedia"
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

    // DUT-640: custom lenient `init(from:)` lives in `WPDTOs+Media.swift`.
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

    // DUT-693: `parseWPDate` + `hasExplicitOffset` + the shared ISO8601
    // formatters live in `WPDTOs+DateParsing.swift` to keep this file under the
    // 400-line file_length cap.

    // MARK: - Comments (US-13 / REG-13)

    /// `/wp/v2/comments` response item. Used by ``WPCommentsClient`` to map
    /// into ``DODDomain.RecipeComment``.
    struct Comment: Decodable {
        let id: Int
        let post: Int
        /// WP serializes the no-parent case as `0`; we normalize at the
        /// domain boundary.
        let parent: Int?
        // DUT-384: optional so one comment with a null/absent `author_name` (a
        // logged-in WP author, a deleted/anonymized author) can't fail the whole
        // page's array decode — same lenience DUT-27 gave `content`.
        let authorName: String?
        let dateGMT: String?
        /// Optional + defaulted to empty at the domain boundary: WordPress can
        /// return content as null/absent for a freshly held comment, and that
        /// must not fail the whole comment decode (DUT-27).
        let content: RenderedString?
        let status: String?
        let authorAvatarURLs: [String: URL]?
        let meta: CommentMeta?

        enum CodingKeys: String, CodingKey {
            case id, post, parent, content, status, meta
            case authorName = "author_name"
            case dateGMT = "date_gmt"
            case authorAvatarURLs = "author_avatar_urls"
        }

        /// Pick the largest Gravatar size WP returned. WP keys the avatar
        /// map by string-encoded pixel sizes ("24", "48", "96"); we prefer
        /// 96 for high-DPI displays.
        var bestAvatarURL: URL? {
            guard let urls = authorAvatarURLs, !urls.isEmpty else { return nil }
            let preferred = ["96", "48", "24"]
            for key in preferred where urls[key] != nil {
                return urls[key]
            }
            // Fallback: pick the highest numeric key present.
            let sortedByPx = urls.compactMap { key, value -> (Int, URL)? in
                Int(key).map { ($0, value) }
            }
            .sorted { $0.0 > $1.0 }
            return sortedByPx.first?.1
        }
    }

    /// Comment meta blob. The only field we read today is the WPRM star
    /// rating. WP may emit the rating as an Int *or* as a numeric String
    /// depending on the meta registration; ``CommentMeta`` accepts both.
    struct CommentMeta: Decodable {
        let wprmCommentRating: Int?

        enum CodingKeys: String, CodingKey {
            case wprmCommentRating = "wprm_comment_rating"
        }

        init(from decoder: Decoder) throws {
            // WordPress serializes an empty / absent comment meta as an empty
            // JSON array ([]) for a freshly held comment, which is NOT a keyed
            // container. Treat that as "no rating" rather than throwing and
            // failing the entire comment decode (DUT-27: the held-comment POST
            // response failed to decode, surfacing "Couldn't read the server's
            // reply" even though the comment posted).
            guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
                self.wprmCommentRating = nil
                return
            }
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .wprmCommentRating) {
                self.wprmCommentRating = intValue
            } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .wprmCommentRating) {
                self.wprmCommentRating = Int(stringValue)
            } else {
                self.wprmCommentRating = nil
            }
        }
    }

    // MARK: - Ratings (US-14 / REG-14)

    /// `/wp-recipe-maker/v1/rating/recipe/<id>` response.
    ///
    /// WPRM's public documentation shows the wrapped shape
    /// `{ "rating": { "average": …, "count": …, "total": … } }`. Older /
    /// alternate plugin builds return the bare object — both decode here so
    /// REG-14's "degrade gracefully" promise holds even if the shape drifts.
    struct WPRMRatingResponse: Decodable {
        let average: Double
        let count: Int

        enum RootKeys: String, CodingKey {
            case rating
        }

        enum InnerKeys: String, CodingKey {
            case average, count, total
        }

        init(from decoder: Decoder) throws {
            // Try wrapped shape first.
            let root = try? decoder.container(keyedBy: RootKeys.self)
            if let inner = try? root?.nestedContainer(keyedBy: InnerKeys.self, forKey: .rating) {
                self.average = Self.decodeDouble(inner, key: .average)
                self.count = Self.decodeInt(inner, key: .count)
                return
            }
            // Fall back to flat shape.
            let flat = try decoder.container(keyedBy: InnerKeys.self)
            self.average = Self.decodeDouble(flat, key: .average)
            self.count = Self.decodeInt(flat, key: .count)
        }

        private static func decodeDouble(
            _ container: KeyedDecodingContainer<InnerKeys>,
            key: InnerKeys
        ) -> Double {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Double(value) ?? 0
            }
            return 0
        }

        private static func decodeInt(
            _ container: KeyedDecodingContainer<InnerKeys>,
            key: InnerKeys
        ) -> Int {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Int(value)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Int(value) ?? 0
            }
            return 0
        }
    }

    // MARK: - Equipment (US-51 / AC-51.1)

    /// A single entry from the WP Recipe Maker recipe-card `equipment` array.
    ///
    /// WPRM serializes each item as
    /// `{ "name": "12\" Dutch Oven", "link": "https://…", "image_url": "https://…" }`.
    /// Only `name` is reliably present; `link` and `image_url` are absent on
    /// most cards and are decoded leniently so a missing/empty/malformed URL
    /// never fails the surrounding recipe-card decode (AC-51.1).
    struct Equipment: Decodable {
        let name: String?
        let link: String?
        let imageURL: String?

        enum CodingKeys: String, CodingKey {
            case name, link
            case imageURL = "image_url"
        }
    }

    /// The slice of a WPRM recipe-card payload we read for equipment. The
    /// card carries many more fields; we decode only `equipment` and ignore
    /// the rest. An absent array decodes to `nil` (→ no equipment).
    struct RecipeCard: Decodable {
        let equipment: [Equipment]?
    }
}

// MARK: - Domain mapping

extension WPDTO.Post {
    /// Map to a `RecipeListItem` for list screens. Hero image URL is filled
    /// in later by the view-model (it requires a follow-up `/media/{id}` call
    /// or use of the featured media link if pre-resolved).
    ///
    /// `categoryIDs` is propagated from the wire payload (T-530 / CL-53 /
    /// REG-17) so the Search-tab category chip can filter fresh REST hits before
    /// a recipe-detail open hydrates `CachedRecipe.categoryIDs`. An omitted field
    /// (`categories == nil`) stays nil, not `[]` — the distinction lets the guard
    /// in `RecipeStore.cache(listItem:)` avoid clobbering a populated value.
    func toRecipeListItem(heroImage: URL?) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: HTMLSanitizer.plainText(from: title.rendered),
            excerpt: HTMLSanitizer.plainText(from: WPDTO.strippingMoreLink(excerpt.rendered)),
            heroImage: heroImage,
            // DUT-311: `date` is site-local; `date_gmt` is genuine UTC, so it
            // drives `publishedAt` (parseWPDate assumes UTC for offsetless input).
            publishedAt: WPDTO.parseWPDate(dateGMT ?? date),
            totalTimeDisplay: nil,
            canonicalURL: link,
            categoryIDs: categories
        )
    }
}

extension WPDTO.Category {
    func toDomain() -> DODDomain.Category {
        // DUT-426: sanitize like every other WP string — category names come
        // HTML-encoded ("Breads &amp; Rolls").
        DODDomain.Category(id: id, name: HTMLSanitizer.plainText(from: name), slug: slug, count: count)
    }
}

extension WPDTO.Equipment {
    /// Map a wire-format equipment entry to the domain type, or `nil` when the
    /// entry is unusable (missing / blank name). Strips HTML from the name and
    /// parses `link` / `image_url` leniently — an empty or malformed URL just
    /// becomes `nil` rather than dropping the whole entry (AC-51.1).
    func toDomain() -> DODDomain.Equipment? {
        let cleanName = HTMLSanitizer.plainText(from: name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        return DODDomain.Equipment(
            name: cleanName,
            imageURL: WPDTO.parseOptionalURL(imageURL),
            link: WPDTO.parseOptionalURL(link)
        )
    }
}

extension WPDTO.RecipeCard {
    /// The recipe's equipment list, ready for the domain. Absent array → `[]`;
    /// entries with no usable name are skipped (AC-51.1). UI surfacing of this
    /// list ("Equipment & Tools" section) is a later slice.
    var equipmentList: [DODDomain.Equipment] {
        (equipment ?? []).compactMap { $0.toDomain() }
    }
}

extension WPDTO {
    /// Parse an optional URL leniently: nil / empty / whitespace / unparseable all collapse to `nil`.
    static func parseOptionalURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

extension WPDTO.Comment {
    /// Map a wire-format comment to the public domain type. Strips HTML,
    /// normalizes parent=0 → nil, decodes unknown status strings to
    /// `.unknown` rather than throwing.
    func toDomain() -> RecipeComment {
        let normalizedParent: Int? = {
            guard let parent, parent > 0 else { return nil }
            return parent
        }()
        let mappedStatus: RecipeComment.Status = {
            guard let raw = status, let value = RecipeComment.Status(rawValue: raw) else {
                return .unknown
            }
            return value
        }()
        return RecipeComment(
            id: id,
            postID: post,
            parentID: normalizedParent,
            authorName: HTMLSanitizer.plainText(from: authorName ?? ""),
            // CL-139: WordPress's public `/wp/v2/comments` GET does NOT
            // include `author_email` in the response (privacy — email is
            // moderation-only data, only visible to admins via the
            // moderation queue or the authenticated `?context=edit` view).
            // The app uses the anonymous public endpoint, so every
            // FETCHED comment carries an empty `authorEmail`. The submit
            // path stamps `profile.email` locally on the just-posted
            // comment so own-comment photos render in-session.
            authorEmail: "",
            avatarURL: bestAvatarURL,
            dateGMT: WPDTO.parseWPDate(dateGMT),
            body: HTMLSanitizer.plainText(from: content?.rendered ?? ""),
            ratingValue: meta?.wprmCommentRating,
            status: mappedStatus
        )
    }
}
