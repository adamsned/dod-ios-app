import DODDomain
import Foundation

/// DUT-392 — a comment plus whether it's a reply, for the threaded render.
struct ThreadedComment: Identifiable {
    let comment: RecipeComment
    let isReply: Bool
    var id: Int { comment.id }
}

/// DUT-392 — turn the flat, newest-first comment list into a threaded order so
/// replies render indented directly beneath the comment they answer, instead of
/// floating mid-thread (a reply is usually newer than its parent, so a flat
/// newest-first list frequently puts the reply ABOVE the comment it answers,
/// reading as a non-sequitur).
///
/// Ordering: top-level comments newest-first; each comment's replies nested
/// oldest-first directly beneath it. A reply whose parent isn't in the loaded
/// set (parent on a later page or still in moderation) is hoisted to top level
/// rather than dropped or floated.
enum CommentThreader {

    static func thread(_ comments: [RecipeComment]) -> [ThreadedComment] {
        let presentIDs = Set(comments.map(\.id))

        // A reply only when its parent is actually present in the loaded set;
        // otherwise it's an orphan and treated as top-level (hoisted).
        func isReply(_ comment: RecipeComment) -> Bool {
            guard let parent = comment.parentID, parent != 0 else { return false }
            return presentIDs.contains(parent)
        }

        let topLevel =
            comments
            .filter { !isReply($0) }
            .sorted { $0.dateGMT > $1.dateGMT }
        let repliesByParent = Dictionary(grouping: comments.filter(isReply)) {
            $0.parentID ?? 0
        }

        var ordered: [ThreadedComment] = []
        for parent in topLevel {
            ordered.append(ThreadedComment(comment: parent, isReply: false))
            let replies = (repliesByParent[parent.id] ?? []).sorted { $0.dateGMT < $1.dateGMT }
            ordered.append(contentsOf: replies.map { ThreadedComment(comment: $0, isReply: true) })
        }
        return ordered
    }
}
