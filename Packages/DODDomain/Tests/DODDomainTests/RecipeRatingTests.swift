import Foundation
import Testing

@testable import DODDomain

/// REG-14 / DUT-376: the `RecipeRating` init clamps `average` to `0.0...5.0`
/// and `count` to `≥ 0`; DUT-376 extends the same defensive treatment to
/// `userRating`, which must land in `1...5` (a star value) when present and
/// stay `nil` when the user hasn't voted.
@Suite("RecipeRating invariants")
struct RecipeRatingTests {

    @Test func userRatingBelowRangeClampsToOne() {
        let rating = RecipeRating(recipeID: 1, average: 3, count: 10, userRating: 0)
        #expect(rating.userRating == 1)
    }

    @Test func userRatingAboveRangeClampsToFive() {
        let rating = RecipeRating(recipeID: 1, average: 3, count: 10, userRating: 6)
        #expect(rating.userRating == 5)
    }

    @Test func inRangeUserRatingIsPreserved() {
        let rating = RecipeRating(recipeID: 1, average: 3, count: 10, userRating: 3)
        #expect(rating.userRating == 3)
    }

    @Test func nilUserRatingStaysNil() {
        let rating = RecipeRating(recipeID: 1, average: 3, count: 10, userRating: nil)
        #expect(rating.userRating == nil)
    }

    /// The existing average/count clamps are unaffected by the new logic.
    @Test func averageAndCountStillClamp() {
        let rating = RecipeRating(recipeID: 1, average: 9, count: -4, userRating: 4)
        #expect(rating.average == 5.0)
        #expect(rating.count == 0)  // swiftlint:disable:this empty_count
        #expect(rating.userRating == 4)
    }

    /// DUT-499: `min(5.0, .nan)`/`max(0.0, min(5.0, .infinity))` both yield 5.0
    /// in Swift, so a non-finite upstream average must be rejected to the
    /// no-rating sentinel (0.0), never rendered as a perfect 5 stars.
    @Test func nanAverageDegradesToZero() {
        let rating = RecipeRating(recipeID: 1, average: .nan, count: 3)
        #expect(rating.average == 0.0)
    }

    @Test func positiveInfinityAverageDegradesToZero() {
        let rating = RecipeRating(recipeID: 1, average: .infinity, count: 3)
        #expect(rating.average == 0.0)
    }

    @Test func negativeInfinityAverageDegradesToZero() {
        let rating = RecipeRating(recipeID: 1, average: -.infinity, count: 3)
        #expect(rating.average == 0.0)
    }

    /// A finite out-of-range value still clamps into 0.0...5.0.
    @Test func aboveRangeAverageClampsToFive() {
        let rating = RecipeRating(recipeID: 1, average: 7.5, count: 3)
        #expect(rating.average == 5.0)
    }

    @Test func negativeAverageClampsToZero() {
        let rating = RecipeRating(recipeID: 1, average: -2.0, count: 3)
        #expect(rating.average == 0.0)
    }

    /// A normal in-range average is passed through untouched.
    @Test func inRangeAverageIsPreserved() {
        let rating = RecipeRating(recipeID: 1, average: 4.2, count: 3)
        #expect(rating.average == 4.2)
    }
}
