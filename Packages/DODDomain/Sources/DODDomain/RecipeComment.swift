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
        self.avatarURL = avatarURL
        self.dateGMT = dateGMT
        self.body = body
        self.ratingValue = ratingValue
        self.status = status
    }
}
