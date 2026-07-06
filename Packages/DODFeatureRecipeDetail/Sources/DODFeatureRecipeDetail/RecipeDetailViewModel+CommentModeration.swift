import DODDomain
import Foundation

// DUT-501 — comment report/block, App Store Review Guideline 1.2. The comment
// list already shows only server-approved comments; these add the in-app
// flag/report + block-user controls Apple requires for any UGC surface. Kept in
// its own file so `RecipeDetailViewModel.swift` stays under the file_length cap.
extension RecipeDetailViewModel {

    /// The comments actually rendered: `comments` minus anything the user
    /// reported (hidden) or authored by a blocked user.
    public var visibleComments: [RecipeComment] {
        comments.filter { commentModeration.isVisible($0) }
    }

    /// Whether to show the report/block affordance on a row — only for OTHER
    /// people's comments (you don't report or block yourself).
    public func canModerate(_ comment: RecipeComment) -> Bool {
        !isOwnComment(comment)
    }

    /// Report a comment: hide it locally immediately (the user stops seeing it)
    /// — the accompanying moderation email (``reportMailtoURL(for:)``) is what
    /// delivers the report to us within the Guideline 1.2 24-hour window.
    public func reportComment(_ comment: RecipeComment) {
        commentModeration.hide(commentID: comment.id)
    }

    /// DUT-546 gap 2 — call after the view attempts to open the report
    /// `mailto:`. `mailtoOpened == false` means the device has no mail account
    /// (or otherwise refused the URL), so the report never reached moderation
    /// even though the row is already hidden. Surface a fallback that hands the
    /// user the published contact address so they can still report, and note
    /// the comment id so the operator can act (Guideline 1.2 expects reports to
    /// be actionable, not just locally hidden). On success we confirm the
    /// report landed so the affordance isn't a silent success either.
    public func acknowledgeReport(of comment: RecipeComment, mailtoOpened: Bool) {
        if mailtoOpened {
            snackbarMessage = "Reported. Thanks — we'll review it."
        } else {
            snackbarMessage = """
                No mail app is set up. Email \(Self.moderationContactEmail) \
                to report comment #\(comment.id).
                """
        }
    }

    /// Block a comment's author: hides every comment from that display name,
    /// app-wide and across relaunches.
    ///
    /// DUT-546 gap 1 — blank-name ("Anonymous") authors can't be name-blocked
    /// (see ``CommentModerationStore/block(author:)``). Rather than silently
    /// no-op the "Block Anonymous" affordance for exactly the low-accountability
    /// authors most likely to post objectionable content, fall back to hiding
    /// that specific comment by id (same mechanism as Report) so the offending
    /// row actually disappears. Either way the user gets snackbar feedback —
    /// no moderation action is a silent no-op.
    public func blockAuthor(of comment: RecipeComment) {
        if commentModeration.block(author: comment.authorName) {
            snackbarMessage = "Blocked \(comment.authorName). Their comments are now hidden."
        } else {
            // Anonymous / blank-name row — hide this comment instead of
            // name-blocking every other anonymous author.
            commentModeration.hide(commentID: comment.id)
            snackbarMessage = "Comment hidden."
        }
    }

    /// Prefilled `mailto:` the row opens on Report so the flagged content
    /// actually reaches moderation (Guideline 1.2 requires reports to be
    /// actionable, not just locally hidden).
    public func reportMailtoURL(for comment: RecipeComment) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.moderationContactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Report comment #\(comment.id)"),
            URLQueryItem(
                name: "body",
                value: """
                    I'm reporting this comment for review:

                    "\(comment.body)"

                    — by \(comment.authorName)
                    Recipe post ID: \(comment.postID)
                    Comment ID: \(comment.id)
                    """
            ),
        ]
        return components.url
    }

    /// True when a comment belongs to the signed-in user (their own posts carry
    /// their profile email; other users' GET comments have an empty email).
    func isOwnComment(_ comment: RecipeComment) -> Bool {
        // DUT-647 tail: trim BOTH sides before the case-insensitive compare. A
        // profile email stored with a stray leading/trailing space (or a wire
        // value with surrounding whitespace) otherwise fails an equality that
        // should match, so the user's own comment loses its profile avatar.
        let charSet = CharacterSet.whitespacesAndNewlines
        let email = profile?.email.lowercased().trimmingCharacters(in: charSet) ?? ""
        guard !email.isEmpty else { return false }
        let commentEmail = comment.authorEmail.lowercased().trimmingCharacters(in: charSet)
        return commentEmail == email
    }

    /// Moderation contact — also the Guideline 1.2 "published contact" surface.
    static var moderationContactEmail: String { "daddy@dutchovendaddy.com" }
}
