import Foundation
import Testing

@testable import DODDesignSystem

/// DUT-320 wave 4: locale-aware decimal rendering for VoiceOver accessibility labels.
/// Prior fixes for this same bug class: DUT-320 (FractionRenderer), DUT-737 (IngredientMetricConverter),
/// PR #768 (CookModeViewModel.speedLabel). This test ensures StarRatingDisplay.accessibilityLabelText
/// respects device locale (comma in de_DE, period in en_US) rather than always using C-locale period.
@Suite("StarRatingDisplay accessibility label locale awareness")
struct StarRatingDisplayLocaleTests {

    /// English locale (en_US) uses a period decimal separator.
    @Test func englishLocaleUsesPeriodsForDecimal() {
        let label = StarRatingDisplay.accessibilityLabelText(
            average: 4.3,
            count: 12,
            locale: Locale(identifier: "en_US")
        )
        #expect(label == "4.3 out of 5 stars, 12 ratings")
    }

    /// German locale (de_DE) uses a comma decimal separator.
    @Test func germanLocaleUsesCommaForDecimal() {
        let label = StarRatingDisplay.accessibilityLabelText(
            average: 4.3,
            count: 12,
            locale: Locale(identifier: "de_DE")
        )
        #expect(label == "4,3 out of 5 stars, 12 ratings")
    }

    /// Whole-number ratings always show exactly one decimal place (e.g., "4.0" not "4").
    /// This behavior matches the prior String(format: "%.1f", ...) implementation.
    @Test func wholeNumberRatingShowsSingleDecimalPlace() {
        let label = StarRatingDisplay.accessibilityLabelText(
            average: 4.0,
            count: 5,
            locale: Locale(identifier: "en_US")
        )
        #expect(label == "4.0 out of 5 stars, 5 ratings")
    }

    /// Singular "rating" vs plural "ratings" phrasing.
    @Test func singularRatingPhraseForOneRating() {
        let label = StarRatingDisplay.accessibilityLabelText(
            average: 3.5,
            count: 1,
            locale: Locale(identifier: "en_US")
        )
        #expect(label == "3.5 out of 5 stars, 1 rating")
    }

    /// French locale (fr_FR) uses comma (like German).
    @Test func frenchLocaleUsesCommaForDecimal() {
        let label = StarRatingDisplay.accessibilityLabelText(
            average: 4.7,
            count: 20,
            locale: Locale(identifier: "fr_FR")
        )
        #expect(label == "4,7 out of 5 stars, 20 ratings")
    }
}
