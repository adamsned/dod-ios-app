import Foundation
import SwiftData

/// Local cache of the aggregate WP Recipe Maker rating for one recipe,
/// plus the star value THIS device's guest identity has submitted (if any).
/// One row per recipe (`recipeID` is the unique key).
///
/// Stores primitive fields rather than a `RecipeRating` Codable blob —
/// keeps this model independent of `DODDomain.RecipeRating` (which lives
/// on the parallel `feat/comments-data` branch). Conversion to the Domain
/// type happens in `RecipeStore`.
///
/// Spec trace: US-13 (rating cache), AC-13.* (one-rating-per-device, can
/// be changed), constitution §4 (offline-first).
@Model
public final class CachedRating {

    /// WP post id of the recipe this rating belongs to.
    public var recipeID: Int

    /// Aggregate average across all rated comments, as WP returned it.
    public var average: Double

    /// Aggregate count across all rated comments.
    public var count: Int

    /// The star value THIS device's guest identity submitted, or `nil` if
    /// the user has never rated this recipe. Used to render the user's
    /// previously-chosen star count when the rating sheet reopens.
    public var userRating: Int?

    /// When this row was last refreshed locally.
    public var cachedAt: Date

    public init(
        recipeID: Int,
        average: Double,
        count: Int,
        userRating: Int? = nil,
        cachedAt: Date = .now
    ) {
        self.recipeID = recipeID
        self.average = average
        self.count = count
        self.userRating = userRating
        self.cachedAt = cachedAt
    }
}
