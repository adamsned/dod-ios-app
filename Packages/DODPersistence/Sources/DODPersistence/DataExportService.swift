import Foundation

/// Serializes a ``DataExportDocument`` to (and from) portable JSON, and writes
/// it to a temporary file for the "Export My Data" share sheet (DUT-162).
///
/// **No network, no schema change.** This is a pure read-and-serialize pass:
/// the caller gathers the on-device sections (the two SwiftData models via
/// ``RecipeStore`` export accessors, plus the shopping list + profile from
/// their own stores) and hands them here. Everything works offline and for a
/// guest user with no account (AC).
///
/// **Human-inspectable JSON (AC).** Encoded pretty-printed, with sorted keys and
/// ISO-8601 dates, so the file reads cleanly in any text editor and the dates
/// round-trip faithfully.
public struct DataExportService: Sendable {

    public init() {}

    /// A JSON encoder tuned for a portable, human-readable, round-trippable
    /// file. `sortedKeys` keeps the field order stable (and diff-friendly);
    /// `.iso8601` renders dates as readable UTC timestamps that decode back to
    /// the same `Date` (at whole-second resolution).
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// The matching decoder (round-trips ``makeEncoder``'s output). Used by the
    /// L1 tests and by any future import path.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Assemble a document from the gathered sections. `exportedAt` is injectable
    /// so tests are deterministic; production defaults to now.
    public func makeDocument(
        savedRecipes: [DataExportSavedRecipe],
        journalEntries: [DataExportJournalEntry],
        shoppingList: [DataExportShoppingListItem],
        profile: DataExportProfile?,
        exportedAt: Date = .now
    ) -> DataExportDocument {
        DataExportDocument(
            exportedAt: exportedAt,
            savedRecipes: savedRecipes,
            journalEntries: journalEntries,
            shoppingList: shoppingList,
            profile: profile
        )
    }

    /// Encode a document to pretty-printed JSON data.
    public func encode(_ document: DataExportDocument) throws -> Data {
        try Self.makeEncoder().encode(document)
    }

    /// Decode a document from JSON data (round-trips ``encode(_:)``).
    public func decode(_ data: Data) throws -> DataExportDocument {
        try Self.makeDecoder().decode(DataExportDocument.self, from: data)
    }

    /// A stable, human-friendly filename for the exported file, e.g.
    /// `DutchOvenDaddy-Export-2026-09-27.json`. Date-only (no time) so a same-day
    /// re-export overwrites rather than piling up temp files.
    public func suggestedFileName(for date: Date = .now, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
        let stamp = String(format: "%04d-%02d-%02d", year, month, day)
        return "DutchOvenDaddy-Export-\(stamp).json"
    }

    /// Encode `document` and write it to a file in `directory` (defaults to the
    /// temporary directory, which is the right place for a throwaway file handed
    /// to the share sheet). Returns the written file URL.
    ///
    /// - Note: `.atomic` so a reader (an AirDrop peer, Files) never sees a
    ///   half-written file.
    @discardableResult
    public func write(
        _ document: DataExportDocument,
        to directory: URL = FileManager.default.temporaryDirectory,
        date: Date = .now
    ) throws -> URL {
        let data = try encode(document)
        let fileURL = directory.appendingPathComponent(suggestedFileName(for: date))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
