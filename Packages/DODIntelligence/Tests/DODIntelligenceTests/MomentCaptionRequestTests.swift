import DODIntelligence
import DODSupport
import XCTest

@Suite
struct MomentCaptionRequestTests {

    @Test
    func entryInitCopiesFieldsAndClampsRating() {
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1,
            recipeTitle: "Skillet Cornbread",
            cookedAt: Date(),
            note: "Kids loved it",
            personalRating: 9
        )

        let request = MomentCaptionRequest(entry: entry)

        XCTAssertEqual(request.recipeTitle, "Skillet Cornbread")
        XCTAssertEqual(request.note, "Kids loved it")
        // Rating should be clamped to 5 (max value)
        XCTAssertEqual(request.personalRating, 5)
    }

    @Test
    func hasMomentFalseForTitleOnly() {
        let request = MomentCaptionRequest(recipeTitle: "X")
        XCTAssertFalse(request.hasMoment)
    }

    @Test
    func hasMomentTrueForNoteOrImage() {
        // Non-blank note gives true
        let requestWithNote = MomentCaptionRequest(recipeTitle: "Test", note: "Great recipe!")
        XCTAssertTrue(requestWithNote.hasMoment)

        // Image data gives true
        let requestWithImage = MomentCaptionRequest(recipeTitle: "Test", imageData: Data([1]))
        XCTAssertTrue(requestWithImage.hasMoment)

        // Whitespace-only note gives false
        let requestWithWhitespaceNote = MomentCaptionRequest(recipeTitle: "Test", note: "   \n  ")
        XCTAssertFalse(requestWithWhitespaceNote.hasMoment)
    }
}
