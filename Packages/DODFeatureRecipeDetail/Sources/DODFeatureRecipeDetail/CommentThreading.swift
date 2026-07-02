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
        let byID = Dictionary(comments.map { ($0.id, $0) }) { first, _ in first }

        // A reply only when its parent is actually present in the loaded set;
        // otherwise it's an orphan and treated as top-level (hoisted).
        func isReply(_ comment: RecipeComment) -> Bool {
            guard let parent = comment.parentID, parent != 0 else { return false }
            return byID[parent] != nil
        }

        // DUT-432: resolve each reply to its nearest TOP-LEVEL ancestor (WP
        // threads nest to depth 5), so a reply-to-a-reply renders — flattened
        // to one indent level under its thread's root — instead of being
        // grouped under a mid-level id the emit loop never visits and silently
        // dropped. The visited set guards a (malformed) parent cycle.
        func topLevelAncestorID(of comment: RecipeComment) -> Int {
            var current = comment
            var visited: Set<Int> = [comment.id]
            while true {
                guard let parentID = current.parentID, parentID != 0,
                    let parent = byID[parentID], visited.insert(parentID).inserted
                else { return current.id }
                current = parent
            }
        }

        let topLevel =
            comments
            .filter { !isReply($0) }
            .sorted { $0.dateGMT > $1.dateGMT }
        let repliesByAncestor = Dictionary(grouping: comments.filter(isReply)) {
            topLevelAncestorID(of: $0)
        }

        var ordered: [ThreadedComment] = []
        for parent in topLevel {
            ordered.append(ThreadedComment(comment: parent, isReply: false))
            let replies = (repliesByAncestor[parent.id] ?? []).sorted { $0.dateGMT < $1.dateGMT }
            ordered.append(contentsOf: replies.map { ThreadedComment(comment: $0, isReply: true) })
        }
        // Malformed-input safety net (a parent CYCLE has no top-level member,
        // so its group key isn't in `topLevel`): hoist stranded groups rather
        // than dropping their comments — never lose a comment.
        let topLevelIDs = Set(topLevel.map(\.id))
        let stranded =
            repliesByAncestor
            .filter { !topLevelIDs.contains($0.key) }
            .values.flatMap { $0 }
            .sorted { $0.dateGMT > $1.dateGMT }
        ordered.append(contentsOf: stranded.map { ThreadedComment(comment: $0, isReply: false) })
        return ordered
    }
}
