import Foundation
import Testing

@testable import DODNetworking

// MARK: - WPRMRatingResponse.decodeInt edge cases

/// Additional edge-case coverage for numeric parsing in untrusted network data.
/// Complements existing tests: WPRMRatingResponseDecodeTests, JSONLDDurationTests,
/// JSONLDRecipeInfoFieldsTests. Focus: missing fields, boundary values, and
/// non-finite/out-of-range Doubles.
@Suite("WPRMRatingResponse.decodeInt edge cases") struct RatingDecodeIntEdgeCasesTests {

    private let decoder = JSONDecoder()

    /// Count field missing entirely from the dict.
    @Test func missingCountFieldDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":4.5}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.average == 4.5)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// Count as empty string "".
    @Test func emptyStringCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":3.0,"count":""}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// Count as string "0" (zero).
    @Test func zeroStringCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":4.0,"count":"0"}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// Count as valid negative integer.
    @Test func negativeIntCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":3.5,"count":-5}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        // Negative counts don't match real-world data; decoder accepts as-is
        #expect(response.count == -5)
    }

    /// Count as negative Double: -3.7 (should truncate toward zero to -3).
    @Test func negativeDoubleCountRoundsTruncatesCorrectly() throws {
        let json = Data(#"{"rating":{"average":2.5,"count":-3.7}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        // Int(exactly: -3.7.rounded(.towardZero)) == Int(exactly: -3.0) == -3
        #expect(response.count == -3)
    }

    /// Count as negative Double that overflows below Int.min.
    @Test func negativeHugeDoubleCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":1.0,"count":-1e308}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// Flat shape (not wrapped) with normal count.
    @Test func flatShapeNormalCountDecodes() throws {
        let json = Data(#"{"average":4.5,"count":42}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.average == 4.5)
        #expect(response.count == 42)
    }

    /// Flat shape with out-of-range Double count.
    @Test func flatShapeOutOfRangeCountDegradesGracefully() throws {
        let json = Data(#"{"average":3.0,"count":1e30}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// Average as very large Double that exceeds Double representable range.
    @Test func largeAverageDecodes() throws {
        let json = Data(#"{"rating":{"average":1e100,"count":5}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        // Huge Double still decodes (Double can represent 1e100)
        #expect(response.average == 1e100)
        #expect(response.count == 5)
    }

    /// Average as NaN (decoded via string "NaN").
    @Test func nanAverageStringDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":"NaN","count":10}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        // String("NaN") is parsed by Double(_:) to Double.nan, which propagates through
        #expect(response.average.isNaN)
        #expect(response.count == 10)
    }
}

// MARK: - parseISO8601Duration edge cases

@Suite("JSONLDRecipeParser.parseISO8601Duration edge cases") struct JSONLDDurationEdgeCasesTests {

    /// Empty string is not valid ISO8601 (doesn't start with P).
    @Test func emptyStringReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("") == nil)
    }

    /// Just "P" with nothing after is malformed.
    @Test func justPWithoutComponentsReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P") == nil)
    }

    /// "PT" with no components is malformed (trailing buffer check).
    @Test func justPTWithoutComponentsReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT") == nil)
    }

    /// "PT0H" represents zero hours, which is zero seconds → nil.
    @Test func zeroHoursReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT0H") == nil)
    }

    /// "P0D" represents zero days → nil.
    @Test func zeroDaysReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P0D") == nil)
    }

    /// Attempt to use negative component "PT-5M" is malformed
    /// (minus sign is not a digit, unit multiplier fails).
    @Test func negativeComponentReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT-5M") == nil)
    }

    /// Unit with no preceding digits "PTM" fails (buffer is empty when unit seen).
    @Test func unitWithoutDigitsReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PTM") == nil)
    }

    /// Lowercase "pt1h30m" is not valid (must start with capital P).
    @Test func lowercasePReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("pt1h30m") == nil)
    }

    /// Space before unit "PT 30 M" is malformed (space is not a digit).
    @Test func spaceBeforeUnitReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT 30 M") == nil)
    }

    /// Date component only "P5D" is valid (5 days = 432000 seconds).
    @Test func dateComponentOnlyDecodes() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P5D") == .seconds(432_000))
    }

    /// Date component with time "P1DT12H" (1 day + 12 hours = 129600 seconds).
    @Test func dateAndTimeComponentsDecode() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P1DT12H") == .seconds(129_600))
    }

    /// Multiple time components "PT1H30M45S" (1h + 30m + 45s = 5445 seconds).
    @Test func multipleTimeComponentsDecode() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT1H30M45S") == .seconds(5445))
    }
}

// MARK: - parseServings edge cases

@Suite("JSONLDRecipeParser.parseServings edge cases") struct ParseServingsEdgeCasesTests {

    /// Double 5.7 rounds to 6 (standard rounding).
    @Test func doubleRoundingUp() {
        #expect(JSONLDRecipeParser.parseServings(5.7) == 6)
    }

    /// Double 5.4 rounds to 5 (standard rounding).
    @Test func doubleRoundingDown() {
        #expect(JSONLDRecipeParser.parseServings(5.4) == 5)
    }

    /// Negative Double -3.5 becomes -4 via rounding, then nil via non-positive check.
    @Test func negativeDoubleReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(-3.5) == nil)
    }

    /// NaN (non-finite) falls through Int(exactly:) to nil.
    @Test func doubleNaNReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(Double.nan) == nil)
    }

    /// Positive infinity falls through Int(exactly:) to nil.
    @Test func doubleInfinityReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(Double.infinity) == nil)
    }

    /// Negative infinity falls through Int(exactly:) to nil.
    @Test func doubleNegativeInfinityReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(-Double.infinity) == nil)
    }

    /// String with surrounding whitespace "  42  " is trimmed to "42".
    @Test func stringWithWhitespaceParses() {
        #expect(JSONLDRecipeParser.parseServings("  42  ") == 42)
    }

    /// String with no leading number "servings 4" returns nil
    /// (split(" ") gives ["servings", "4"], first is "servings" which doesn't parse).
    @Test func stringWithNoLeadingNumberReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings("servings 4") == nil)
    }

    /// Array with string that has no leading number ["xyz servings"].
    @Test func arrayWithNonNumericStringReturnsNil() {
        let raw: Any = ["xyz servings"]
        #expect(JSONLDRecipeParser.parseServings(raw) == nil)
    }

    /// Array with multiple elements takes the first [6, 8].
    @Test func arrayTakesFirstElement() {
        let raw: Any = [6, 8]
        #expect(JSONLDRecipeParser.parseServings(raw) == 6)
    }

    /// Array with nested string array (first element is array) → recurse.
    @Test func arrayWithNestedArrayTakesFirst() {
        let raw: Any = [["4 servings"]]
        #expect(JSONLDRecipeParser.parseServings(raw) == 4)
    }

    /// Empty array returns nil.
    @Test func emptyArrayReturnsNil() {
        let raw: Any = [] as [Any]
        #expect(JSONLDRecipeParser.parseServings(raw) == nil)
    }
}

// MARK: - mapNutrition edge cases

@Suite("JSONLDRecipeParser.mapNutrition edge cases") struct MapNutritionEdgeCasesTests {

    /// nil input returns nil.
    @Test func nilInputReturnsNil() {
        #expect(JSONLDRecipeParser.mapNutrition(nil) == nil)
    }

    /// Non-dict input (array) returns nil.
    @Test func arrayInputReturnsNil() {
        let raw: Any = ["250 kcal"]
        #expect(JSONLDRecipeParser.mapNutrition(raw) == nil)
    }

    /// Non-dict input (string) returns nil.
    @Test func stringInputReturnsNil() {
        #expect(JSONLDRecipeParser.mapNutrition("250 kcal") == nil)
    }

    /// Non-dict input (number) returns nil.
    @Test func numberInputReturnsNil() {
        #expect(JSONLDRecipeParser.mapNutrition(250) == nil)
    }

    /// Dict with all null values (every field is nil).
    @Test func dictWithAllNullValuesReturnsAllNil() {
        let nutrition = JSONLDRecipeParser.mapNutrition(
            ["calories": NSNull(), "proteinContent": NSNull()]
        )
        #expect(nutrition?.calories == nil)
        #expect(nutrition?.proteinGrams == nil)
        #expect(nutrition?.servingSize == nil)
        #expect(nutrition?.carbsGrams == nil)
        #expect(nutrition?.fatGrams == nil)
    }

    /// Dict with numeric value for a field (non-string).
    @Test func numericFieldReturnsNil() {
        // calories is a number, not a string → clean() returns nil
        let nutrition = JSONLDRecipeParser.mapNutrition(["calories": 250])
        #expect(nutrition?.calories == nil)
    }

    /// Empty string for each field becomes empty string (not nil, since field is present).
    /// Missing fields stay nil; present fields are sanitized regardless of content.
    @Test func emptyStringFieldsBecomeEmptyStrings() {
        let nutrition = JSONLDRecipeParser.mapNutrition(
            [
                "calories": "",
                "proteinContent": "",
                "carbohydrateContent": "",
                "fatContent": "",
                "servingSize": "",
            ]
        )
        #expect(nutrition?.calories?.isEmpty ?? false)
        #expect(nutrition?.proteinGrams?.isEmpty ?? false)
        #expect(nutrition?.carbsGrams?.isEmpty ?? false)
        #expect(nutrition?.fatGrams?.isEmpty ?? false)
        #expect(nutrition?.servingSize?.isEmpty ?? false)
    }

    /// Valid nutrition object populates all fields.
    @Test func validNutritionPopulatesAllFields() {
        let nutrition = JSONLDRecipeParser.mapNutrition(
            [
                "calories": "250 kcal",
                "proteinContent": "12g",
                "carbohydrateContent": "35g",
                "fatContent": "8g",
                "servingSize": "1 cup",
            ]
        )
        #expect(nutrition?.calories == "250 kcal")
        #expect(nutrition?.proteinGrams == "12g")
        #expect(nutrition?.carbsGrams == "35g")
        #expect(nutrition?.fatGrams == "8g")
        #expect(nutrition?.servingSize == "1 cup")
    }
}
