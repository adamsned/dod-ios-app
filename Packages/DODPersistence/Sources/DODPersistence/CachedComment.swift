import Foundation
import SwiftData

/// Local cache of one WordPress comment on a recipe post. Populated when
/// the comment feed for a recipe is fetched, replayed on offline open so
/// readers can still see the conversation while disconnected (US-14).
///
/// Stores primitive fields rather than a `RecipeComment` Codable blob —
/// keeps this model independent of `DODDomain.RecipeComment` (which lives
/// on the parallel `feat/comments-data` branch) and lets `RecipeStore`
/// stitch the Domain type together via a free conversion function once
/// both branches land on `main`.
///
/// Spec trace: US-14 (comment cache + offline read), AC-14.* (pending
/// surfacing), constitution §4 (offline-first).
@Model
public final class CachedComment {

    /// WordPress comment id (unique within the WP install).
    @Attribute(.unique) public var id: Int

    /// WP post id the comment belongs to. Used as the foreign-key for
    /// `cachedComments(forPostID:)`.
    public var postID: Int

    /// Parent comment id when this is a reply, else `nil`.
    public var parentID: Int?

    /// Display name as WP echoed it back (already HTML-decoded by the
    /// network layer).
    public var authorName: String

    /// Avatar URL — may be `nil` when WP returns an empty Gravatar.
    public var avatarURLString: String?

    /// Posted-at timestamp in GMT. The view layer converts to local for
    /// display.
    public var dateGMT: Date

    /// Comment body as plain text (already HTML-stripped).
    public var bodyText: String

    /// Star rating attached to the comment if the user submitted a rating
    /// at the same time, else `nil`. WP Recipe Maker stores ratings on the
    /// comment row.
    public var ratingValue: Int?

    /// Raw `RecipeComment.Status` rawValue. Persisted as `String` so the
    /// schema doesn't need a SwiftData-aware enum encoding — conversion to
    /// the Domain enum happens in `RecipeStore`.
    public var statusRaw: String

    /// When this row was last refreshed locally. Lets the comment feed
    /// view layer show a "cached as of …" line on offline open.
    public var cachedAt: Date

    /// True when this row was posted by THIS device's guest identity and
    /// is currently in WP's moderation queue. Surfacing rule (US-14): the
    /// public list hides it for everyone, but the author still sees their
    /// own comment with an "Awaiting approval" label so they don't think
    /// the submit silently failed.
    public var isPendingFromThisDevice: Bool

    public init(
        id: Int,
        postID: Int,
        parentID: Int? = nil,
        authorName: String,
        avatarURLString: String? = nil,
        dateGMT: Date,
        bodyText: String,
        ratingValue: Int? = nil,
        statusRaw: String,
        cachedAt: Date = .now,
        isPendingFromThisDevice: Bool = false
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.authorName = authorName
        self.avatarURLString = avatarURLString
        self.dateGMT = dateGMT
        self.bodyText = bodyText
        self.ratingValue = ratingValue
        self.statusRaw = statusRaw
        self.cachedAt = cachedAt
        self.isPendingFromThisDevice = isPendingFromThisDevice
    }
}
