import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// DUT-162 — L1 coverage for "Export My Data": the serialization round-trip, the
/// empty-sections path, and the `RecipeStore` accessors that read the two
/// SwiftData models into the export shapes.
@Suite("Export My Data (DUT-162)")
struct DataExportTests {

    // Whole-second dates so the `.iso8601` (sub-second-truncating) encoding
    // round-trips to an EQUAL `Date`.
    private static let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let cookedAt = Date(timeIntervalSince1970: 1_699_000_000)
    private static let savedAt = Date(timeIntervalSince1970: 1_698_000_000)
    private static let publishedAt = Date(timeIntervalSince1970: 1_690_000_000)

    /// Non-force-unwrapping UUID literal (SwiftLint bans `!`). The strings are
    /// valid, so the fallback never fires; it just keeps the call total.
    private func uuid(_ string: String) -> UUID {
        UUID(uuidString: string) ?? UUID()
    }

    private func populatedDocument() -> DataExportDocument {
        DataExportDocument(
            exportedAt: Self.exportedAt,
            savedRecipes: [
                DataExportSavedRecipe(
                    id: 42,
                    title: "Smoked Brisket",
                    excerpt: "Low and slow.",
                    canonicalURL: "https://www.dutchovendaddy.com/r/42/",
                    heroImageURL: "https://www.dutchovendaddy.com/hero/42.jpg",
                    totalSeconds: 43_200,
                    publishedAt: Self.publishedAt,
                    savedAt: Self.savedAt,
                    isArticle: false
                )
            ],
            journalEntries: [
                DataExportJournalEntry(
                    id: uuid("11111111-1111-1111-1111-111111111111"),
                    recipeID: 42,
                    recipeTitle: "Smoked Brisket",
                    cookedAt: Self.cookedAt,
                    note: "Used less salt.",
                    personalRating: 5,
                    photoLocalID: "photo-1"
                )
            ],
            shoppingList: [
                DataExportShoppingListItem(
                    id: uuid("22222222-2222-2222-2222-222222222222"),
                    ingredientText: "2 cups diced yellow onion",
                    recipeTitle: "Smoked Brisket",
                    aisle: "produce",
                    isChecked: true,
                    alreadyHave: false
                )
            ],
            profile: DataExportProfile(
                id: uuid("33333333-3333-3333-3333-333333333333"),
                displayName: "Spencer",
                email: "chef@example.com",
                photoFilename: "avatar.jpg"
            )
        )
    }

    // MARK: - Serialization round-trip

    /// Every section's key fields (titles, notes, dates, quantities) survive an
    /// encode -> decode cycle byte-faithfully.
    @Test func roundTripsAllSectionsFaithfully() throws {
        let service = DataExportService()
        let original = populatedDocument()

        let data = try service.encode(original)
        let decoded = try service.decode(data)

        #expect(decoded == original)
        #expect(decoded.savedRecipes.first?.title == "Smoked Brisket")
        #expect(decoded.savedRecipes.first?.totalSeconds == 43_200)
        #expect(decoded.journalEntries.first?.note == "Used less salt.")
        #expect(decoded.journalEntries.first?.personalRating == 5)
        #expect(decoded.journalEntries.first?.cookedAt == Self.cookedAt)
        #expect(decoded.shoppingList.first?.ingredientText == "2 cups diced yellow onion")
        #expect(decoded.shoppingList.first?.isChecked == true)
        #expect(decoded.profile?.email == "chef@example.com")
        #expect(decoded.exportedAt == Self.exportedAt)
    }

    /// An export with nothing saved still produces a valid document with empty
    /// sections (and a nil profile) — no crash, no failure (AC).
    @Test func emptyCategoriesEncodeAndDecodeGracefully() throws {
        let service = DataExportService()
        let empty = service.makeDocument(
            savedRecipes: [],
            journalEntries: [],
            shoppingList: [],
            profile: nil,
            exportedAt: Self.exportedAt
        )

        let data = try service.encode(empty)
        let decoded = try service.decode(data)

        #expect(decoded.savedRecipes.isEmpty)
        #expect(decoded.journalEntries.isEmpty)
        #expect(decoded.shoppingList.isEmpty)
        #expect(decoded.profile == nil)
        #expect(decoded.schemaVersion == DataExportDocument.currentSchemaVersion)
    }

    /// The file is self-describing / human-inspectable: pretty-printed, with the
    /// documented top-level keys and a non-empty readme sentence (AC).
    @Test func jsonIsHumanInspectable() throws {
        let service = DataExportService()
        let data = try service.encode(populatedDocument())
        let json = try #require(String(bytes: data, encoding: .utf8))

        // Pretty-printed (newlines + indentation) and labeled.
        #expect(json.contains("\n"))
        #expect(json.contains("\"schemaVersion\""))
        #expect(json.contains("\"readme\""))
        #expect(json.contains("\"savedRecipes\""))
        #expect(json.contains("\"journalEntries\""))
        #expect(json.contains("\"shoppingList\""))
        #expect(json.contains("\"profile\""))
        #expect(!DataExportDocument.readmeText.isEmpty)
    }

    /// `write(_:)` produces a real file that decodes back to the same document.
    @Test func writeProducesAReadableFile() throws {
        let service = DataExportService()
        let document = populatedDocument()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try service.write(document, to: directory, date: Self.exportedAt)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.lastPathComponent.hasSuffix(".json"))

        let reread = try service.decode(Data(contentsOf: url))
        #expect(reread == document)
    }

    /// The filename is date-stamped and stable for a given day.
    @Test func suggestedFileNameIsDateStamped() {
        let service = DataExportService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        // 2023-11-14 UTC (1_700_000_000).
        let name = service.suggestedFileName(for: Self.exportedAt, calendar: calendar)
        #expect(name == "DutchOvenDaddy-Export-2023-11-14.json")
    }

    // MARK: - RecipeStore SwiftData accessors

    /// A seeded store exports its saved recipe + cook-log entry into the export
    /// shapes with the key fields intact.
    @Test func storeExportsSavedRecipesAndJournal() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 7, title: "Chili"))
        try await store.markSaved(id: 7)
        try await store.logCook(
            CookLogEntry(
                id: uuid("44444444-4444-4444-4444-444444444444"),
                recipeID: 7,
                recipeTitle: "Chili",
                cookedAt: Self.cookedAt,
                note: "Extra cumin.",
                personalRating: 4
            )
        )

        let saved = try await store.exportedSavedRecipes()
        let journal = try await store.exportedJournalEntries()

        #expect(saved.count == 1)
        #expect(saved.first?.id == 7)
        #expect(saved.first?.title == "Chili")
        #expect(saved.first?.isArticle == false)

        #expect(journal.count == 1)
        #expect(journal.first?.recipeTitle == "Chili")
        #expect(journal.first?.note == "Extra cumin.")
        #expect(journal.first?.personalRating == 4)
        #expect(journal.first?.cookedAt == Self.cookedAt)
    }

    /// An untouched store exports empty sections (no crash) — the guest /
    /// nothing-saved path (AC).
    @Test func emptyStoreExportsEmptySections() async throws {
        let store = try await makeStore()

        let saved = try await store.exportedSavedRecipes()
        let journal = try await store.exportedJournalEntries()

        #expect(saved.isEmpty)
        #expect(journal.isEmpty)
    }
}
