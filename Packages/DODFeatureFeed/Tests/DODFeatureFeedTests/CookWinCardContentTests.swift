import Foundation
import Testing

@testable import DODFeatureFeed
@testable import DODSupport

@Suite struct CookWinCardContentTests {
    private func entry(note: String?) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Lasagna", cookedAt: Date(), note: note)
    }

    @Test func headlineFallsBackToDishTitleWhenNoNote() {
        #expect(CookWinCardContent(entry: entry(note: nil)).headline == "I made Lasagna!")
    }
}
