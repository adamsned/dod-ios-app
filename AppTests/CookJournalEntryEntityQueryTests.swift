import DODSupport
import Foundation
import XCTest

@testable import DODApp

@Suite("CookJournalEntryEntityQuery filter")
struct CookJournalEntryEntityQueryTests {
    @Test("matchesRecipeTitleCaseInsensitively")
    func matchesRecipeTitleCaseInsensitively() {
        let entries = [
            CookLogEntry(
                id: UUID(),
                recipeID: 1,
                recipeTitle: "Lasagna",
                cookedAt: Date(),
                note: nil,
                photoLocalID: nil
            ),
            CookLogEntry(
                id: UUID(),
                recipeID: 2,
                recipeTitle: "Chili",
                cookedAt: Date(),
                note: nil,
                photoLocalID: nil
            ),
        ]

        let result = CookJournalEntryEntityQuery.filter(entries, matching: "lasagna")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].recipeTitle, "Lasagna")
    }

    @Test("matchesNote")
    func matchesNote() {
        let entries = [
            CookLogEntry(
                id: UUID(),
                recipeID: 1,
                recipeTitle: "Lasagna",
                cookedAt: Date(),
                note: "Sunday dinner",
                photoLocalID: nil
            )
        ]

        let result = CookJournalEntryEntityQuery.filter(entries, matching: "sunday")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].note, "Sunday dinner")
    }

    @Test("emptyQueryReturnsNothing")
    func emptyQueryReturnsNothing() {
        let entries = [
            CookLogEntry(
                id: UUID(),
                recipeID: 1,
                recipeTitle: "Lasagna",
                cookedAt: Date(),
                note: nil,
                photoLocalID: nil
            )
        ]

        let result = CookJournalEntryEntityQuery.filter(entries, matching: "  ")
        XCTAssertEqual(result.count, 0)
    }
}
