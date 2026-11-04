import Foundation
import XCTest

@testable import DODSupport

final class CookMomentShareTextFormatterTests: XCTestCase {

    private func makeTestEntry() -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: 1,
            recipeTitle: "Skillet Cornbread",
            cookedAt: Date(),
            note: "secret note"
        )
    }

    func test_fallbackWhenNoCaption() {
        let entry = makeTestEntry()
        let result = CookMomentShareTextFormatter.text(caption: nil, entry: entry)
        XCTAssertEqual(result, "I made Skillet Cornbread!")

        // Test whitespace-only caption
        let result2 = CookMomentShareTextFormatter.text(caption: "   ", entry: entry)
        XCTAssertEqual(result2, "I made Skillet Cornbread!")
    }

    func test_captionThenTitleLine() {
        let entry = makeTestEntry()
        let result = CookMomentShareTextFormatter.text(caption: "Nailed it.", entry: entry)
        XCTAssertEqual(result, "Nailed it.\n— Skillet Cornbread")
    }

    func test_appendsRecipeURL() {
        let entry = makeTestEntry()
        let url = URL(string: "https://example.com/recipe/123")!
        let result = CookMomentShareTextFormatter.text(caption: "Nailed it.", entry: entry, recipeURL: url)
        XCTAssertEqual(result, "Nailed it.\n— Skillet Cornbread\nhttps://example.com/recipe/123")
    }

    func test_neverLeaksPrivateNote() {
        let entry = makeTestEntry()
        let result = CookMomentShareTextFormatter.text(caption: "Nailed it.", entry: entry)
        XCTAssertFalse(result.contains("secret note"))

        // Test with no caption
        let result2 = CookMomentShareTextFormatter.text(caption: nil, entry: entry)
        XCTAssertFalse(result2.contains("secret note"))
    }
}
