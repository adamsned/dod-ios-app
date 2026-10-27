import DODSupport
import Foundation
import Testing

@testable import DODApp

@Suite("CookJournalEntryEntity")
struct CookJournalEntryEntityTests {
    @Test("attributeSetUsesTitleNoteAndDate")
    func attributeSetUsesTitleNoteAndDate() {
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 7,
            recipeTitle: "Lasagna",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Sunday dinner"
        )

        let entity = CookJournalEntryEntity(entry: entry)
        let set = entity.attributeSet

        #expect(set.displayName == "Lasagna")
        #expect(set.title == "I made Lasagna")
        #expect(set.contentDescription?.contains("Sunday dinner") == true)
        #expect(set.keywords?.contains("Lasagna") == true)
    }

    @Test("emptyNoteFallsBackToDate")
    func emptyNoteFallsBackToDate() {
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 7,
            recipeTitle: "Lasagna",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: nil
        )

        let entity = CookJournalEntryEntity(entry: entry)
        let set = entity.attributeSet

        #expect(set.contentDescription?.starts(with: "Cooked on") == true)
    }
}
