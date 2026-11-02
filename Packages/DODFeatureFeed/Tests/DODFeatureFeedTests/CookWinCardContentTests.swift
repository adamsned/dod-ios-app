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

    @Test func headlineUsesFirstNonEmptyNoteLine() {
        let card = CookWinCardContent(entry: entry(note: "\n  My first lasagna, fed 8\nmore text"))
        #expect(card.headline == "My first lasagna, fed 8")
    }

    @Test func winIsCappedAt140Characters() {
        let card = CookWinCardContent(entry: entry(note: String(repeating: "a", count: 300)))
        #expect(card.win?.count == 140)
    }

    @Test func shareCaptionEndsWithAttribution() {
        let card = CookWinCardContent(entry: entry(note: nil))
        #expect(card.shareCaption == "I made Lasagna! — Made with Dutch Oven Daddy")
        #expect(card.shareCaption.hasSuffix(CookWinCardContent.attribution))
    }
}
