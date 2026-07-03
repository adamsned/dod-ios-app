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

    /// Block a comment's author: hides every comment from that display name,
    /// app-wide and across relaunches.
    public func blockAuthor(of comment: RecipeComment) {
        commentModeration.block(author: comment.authorName)
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
        guard let email = profile?.email.lowercased(), !email.isEmpty else { return false }
        return comment.authorEmail.lowercased() == email
    }

    /// Moderation contact — also the Guideline 1.2 "published contact" surface.
    /// Confirm/replace with the real moderation inbox before release.
    static var moderationContactEmail: String { "support@dutchovendaddy.com" }
}
