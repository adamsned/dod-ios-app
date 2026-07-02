import Foundation

/// Aggregate rating summary for a single recipe. Combines the public WPRM
/// summary (average + count) with this device's own posted rating, if any.
///
/// Spec trace: spec.md US-14 (read and submit a star rating) and REG-14
/// (rating average must stay within 0.0...5.0 and count must be ≥ 0 even
/// when the upstream endpoint is unreachable — the client degrades to a
/// zero-valued summary rather than throwing).
public struct RecipeRating: Sendable, Hashable, Codable {

    /// WPRM recipe ID (the inner recipe block ID — *not* the parent WP post
    /// ID). Same identifier WPRM uses in
    /// `/wp-recipe-maker/v1/rating/recipe/<id>`.
    public let recipeID: Int

    /// Mean of all submitted ratings, clamped to `0.0...5.0`. Comes back as
    /// `0.0` when no ratings exist or when the endpoint degraded.
    public let average: Double

    /// Number of submitted ratings backing the average. Always ≥ 0.
    public let count: Int

    /// 1...5 if this device's identity (the email used by the comment form)
    /// has already submitted a rating. `nil` if the user has not voted.
    /// WPRM dedupes by email, so repeat posts overwrite a previous vote.
    public let userRating: Int?

    public init(
        recipeID: Int,
        average: Double,
        count: Int,
        userRating: Int? = nil
    ) {
        self.recipeID = recipeID
        // Defensive clamp — REG-14 promises this invariant to consumers.
        self.average = max(0.0, min(5.0, average))
        self.count = max(0, count)
        // DUT-376: clamp a present vote to the valid 1...5 star range (nil — the
        // "hasn't voted" case — is preserved), matching the average/count guards.
        self.userRating = userRating.map { max(1, min(5, $0)) }
    }
}
