import DODDomain
import Foundation
import Observation

/// DUT-501 — local moderation controls for displayed user comments, required by
/// App Store Review Guideline 1.2 (any app showing user-generated content must
/// let users flag/report objectionable content AND block abusive users, on top
/// of the server-side pre-moderation the comment queue already provides).
///
/// Holds two persisted, app-global sets:
/// - **blocked authors** — normalized display names the user chose to block;
///   every comment from a blocked author is hidden everywhere.
/// - **hidden comment ids** — individual comments the user reported, hidden
///   locally the instant they report (so they no longer have to see it).
///
/// Blocking keys on the display NAME because the public WP `/comments` GET does
/// not return `author_email` (it's moderation-only), so the name is the only
/// stable identifier available for another user's comment. Both sets survive
/// relaunch via `UserDefaults` (injectable so tests use an isolated suite).
@Observable
@MainActor
public final class CommentModerationStore {

    public private(set) var blockedAuthors: Set<String>
    public private(set) var hiddenCommentIDs: Set<Int>

    @ObservationIgnored private let defaults: UserDefaults
    private static let blockedKey = "dod.moderation.blockedAuthorsV1"
    private static let hiddenKey = "dod.moderation.hiddenCommentIDsV1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        blockedAuthors = Set((defaults.array(forKey: Self.blockedKey) as? [String]) ?? [])
        hiddenCommentIDs = Set((defaults.array(forKey: Self.hiddenKey) as? [Int]) ?? [])
    }

    /// A comment is shown unless the user reported (hid) it or blocked its author.
    public func isVisible(_ comment: RecipeComment) -> Bool {
        !hiddenCommentIDs.contains(comment.id)
            && !blockedAuthors.contains(Self.authorKey(comment.authorName))
    }

    /// Block an author by normalized display name — hides all their comments.
    ///
    /// DUT-546 gap 1: returns `false` (and inserts nothing) when the name
    /// resolves to the empty "Anonymous" key, so a blank-name author can't be
    /// name-blocked (it would collateral-block every other blank-name comment
    /// too, and the caller has no visible author to attribute the block to).
    /// The view model falls back to ``hide(commentID:)`` for that row so the
    /// "Block Anonymous" affordance still hides the offending comment instead
    /// of silently no-op'ing. Returning the outcome lets the caller give
    /// feedback rather than assume success.
    @discardableResult
    public func block(author name: String) -> Bool {
        let key = Self.authorKey(name)
        guard !key.isEmpty else { return false }
        blockedAuthors.insert(key)
        defaults.set(Array(blockedAuthors), forKey: Self.blockedKey)
        return true
    }

    /// DUT-546 gap 1 — `true` when a display name is blank/whitespace and thus
    /// resolves to the "Anonymous" fallback, i.e. can't be name-blocked. The
    /// view layer uses this to relabel/route the block affordance for
    /// anonymous rows (block-by-comment-id instead of block-by-name).
    public static func isAnonymous(author name: String) -> Bool {
        authorKey(name).isEmpty
    }

    /// Hide a specific reported comment locally (immediate; the report itself is
    /// sent to moderation separately).
    public func hide(commentID: Int) {
        hiddenCommentIDs.insert(commentID)
        defaults.set(Array(hiddenCommentIDs), forKey: Self.hiddenKey)
    }

    /// Normalize an author name for stable matching (trim + case-fold).
    static func authorKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
