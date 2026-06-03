import Foundation

/// A single reader comment on a recipe post. Sourced from the WP REST
/// `/wp/v2/comments` endpoint (with `_embed=author` so avatars come back in
/// the same round trip).
///
/// Spec trace: spec.md US-13 (read comments on a recipe) and REG-13
/// (comments contract — every approved comment must round-trip body, author
/// name, avatar, GMT date, and optional WPRM star rating).
public struct RecipeComment: Sendable, Hashable, Identifiable, Codable {

    /// WP comment ID. Stable across paginated fetches.
    public let id: Int

    /// The recipe post ID this comment belongs to.
    public let postID: Int

    /// Parent comment ID if this is a reply; `nil` for top-level comments.
    /// WP serializes `0` for no-parent — we normalize that to `nil` at the
    /// client boundary so callers don't need to special-case it.
    public let parentID: Int?

    /// Display name as entered by the commenter. May be empty for anonymous
    /// comments — view layer handles the "Anonymous" fallback.
    public let authorName: String

    /// US-44 / CL-139 / DUT-36 Phase d — commenter email. Almost always
    /// empty (`""`) at the wire boundary: WordPress's public `/wp/v2/comments`
    /// GET does NOT include `author_email` in the response (privacy — email
    /// is moderation-only data only visible to admins). The submit path
    /// stamps this field locally on the just-posted comment so own-comment
    /// rendering can render the user's profile photo immediately in-session.
    /// `Codable` synthesis uses the empty-string default for older cached
    /// JSON that pre-dates Phase d. AC-44.13.
    public let authorEmail: String

    /// Highest-resolution Gravatar URL the API returned (96px when
    /// available). `nil` if the API returned no avatar map.
    public let avatarURL: URL?

    /// UTC timestamp of when the comment was posted. We always store the GMT
    /// variant so display layers can render in the device locale without
    /// re-doing the timezone math.
    public let dateGMT: Date

    /// Plain-text body. HTML stripped via `HTMLSanitizer.plainText(from:)` at
    /// the client boundary so consumers never see `<p>` or entities. The WPRM
    /// star image (e.g. `<img class="wprm-comment-rating">`) gets stripped
    /// too — the star value is surfaced separately via ``ratingValue``.
    public let body: String

    /// 1...5 if this comment carries a WPRM star rating from
    /// `meta.wprm_comment_rating`; `nil` if the commenter didn't rate.
    /// Spec trace: REG-13 (per-comment rating round-trips).
    public let ratingValue: Int?

    /// Moderation status from WP. Unknown values from a future WP/WPRM
    /// upgrade decode to ``Status/unknown`` rather than throwing — the view
    /// layer can then degrade gracefully.
    public let status: Status

    /// Moderation status from `wp/v2/comments.status`.
    public enum Status: String, Sendable, Codable {
        case approved
        case hold
        case spam
        case trash
        case unknown
    }

    public init(
        id: Int,
        postID: Int,
        parentID: Int? = nil,
        authorName: String,
        authorEmail: String = "",
        avatarURL: URL? = nil,
        dateGMT: Date,
        body: String,
        ratingValue: Int? = nil,
        status: Status
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.avatarURL = avatarURL
        self.dateGMT = dateGMT
        self.body = body
        self.ratingValue = ratingValue
        self.status = status
    }

    // MARK: - Codable

    /// Custom decoder defaults `authorEmail` to `""` when the field is
    /// absent from the JSON — keeps older cached comments (encoded before
    /// CL-139 added the field) decoding cleanly without a schema bump.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.postID = try container.decode(Int.self, forKey: .postID)
        self.parentID = try container.decodeIfPresent(Int.self, forKey: .parentID)
        self.authorName = try container.decode(String.self, forKey: .authorName)
        self.authorEmail = try container.decodeIfPresent(String.self, forKey: .authorEmail) ?? ""
        self.avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        self.dateGMT = try container.decode(Date.self, forKey: .dateGMT)
        self.body = try container.decode(String.self, forKey: .body)
        self.ratingValue = try container.decodeIfPresent(Int.self, forKey: .ratingValue)
        self.status = try container.decode(Status.self, forKey: .status)
    }

    /// `Codable` keys mirror the property names — `authorEmail` is a new
    /// CL-139 field; the custom `init(from:)` above tolerates older JSON
    /// without it.
    enum CodingKeys: String, CodingKey {
        case id, postID, parentID, authorName, authorEmail, avatarURL
        case dateGMT, body, ratingValue, status
    }
}
