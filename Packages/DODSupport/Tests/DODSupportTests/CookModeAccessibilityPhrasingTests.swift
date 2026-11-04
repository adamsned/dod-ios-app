import XCTest

@testable import DODSupport

final class CookModeAccessibilityPhrasingTests: XCTestCase {

    func testStepLabelReadsPositionThenText() {
        let result = CookModeAccessibilityPhrasing.stepLabel(number: 3, total: 8, text: " Sear. ")
        XCTAssertEqual(result, "Step 3 of 8. Sear.")
    }

    func testStepLabelEmptyTextOmitsBody() {
        let result = CookModeAccessibilityPhrasing.stepLabel(number: 1, total: 5, text: "   ")
        XCTAssertEqual(result, "Step 1 of 5.")
    }

    func testVoiceModeAnnouncementIsPositionOnly() {
        let result = CookModeAccessibilityPhrasing.stepChangeAnnouncement(
            number: 2,
            total: 8,
            text: "Preheat the oven.",
            voiceModeOn: true
        )
        XCTAssertEqual(result, "Step 2 of 8")
    }

    func testTimerStatusPluralisation() {
        // 270 -> "4 minutes 30 seconds remaining"
        XCTAssertEqual(
            CookModeAccessibilityPhrasing.timerStatus(remainingSeconds: 270),
            "4 minutes 30 seconds remaining"
        )

        // 60 -> "1 minute remaining"
        XCTAssertEqual(
            CookModeAccessibilityPhrasing.timerStatus(remainingSeconds: 60),
            "1 minute remaining"
        )

        // 0 -> "0 seconds remaining"
        XCTAssertEqual(
            CookModeAccessibilityPhrasing.timerStatus(remainingSeconds: 0),
            "0 seconds remaining"
        )
    }

    func testIngredientsSummaryEmptyAndNonEmpty() {
        // Empty ingredients
        XCTAssertEqual(
            CookModeAccessibilityPhrasing.ingredientsSummary([]),
            "No listed ingredients for this step."
        )

        // Non-empty ingredients
        XCTAssertEqual(
            CookModeAccessibilityPhrasing.ingredientsSummary(["flour", "sugar"]),
            "Ingredients for this step: flour, sugar."
        )
    }
}
