import DODSupport
import Foundation
import SwiftData

/// Cook-journal persistence (US-48 / DUT-104) — the store side of the "I Made
/// This" journal. CRUD over the local-only `CachedCookLogEntry`, converting
/// to/from the pure ``CookLogEntry`` value type at the boundary so the schema
/// stays primitive-only (the same Cached*↔value pattern as comments/ratings).
///
/// The pure ``CookLogStats`` calculator runs over the `[CookLogEntry]` that
/// ``allCookLogs()`` returns, so streaks / most-cooked / busiest-month need no
/// store logic of their own.
extension RecipeStore {

    /// Append one cook to the private journal.
    public func logCook(_ entry: CookLogEntry) throws {
        modelContext.insert(
            CachedCookLogEntry(
                id: entry.id,
                recipeID: entry.recipeID,
                recipeTitle: entry.recipeTitle,
                cookedAt: entry.cookedAt,
                note: entry.note,
                personalRating: entry.personalRating,
                photoLocalID: entry.photoLocalID
            )
        )
        try modelContext.save()
    }

    /// Every logged cook, newest first.
    public func allCookLogs() throws -> [CookLogEntry] {
        let descriptor = FetchDescriptor<CachedCookLogEntry>(
            sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.toDomain)
    }

    /// Delete one journal entry by id (no-op if it isn't there).
    public func deleteCookLog(id: UUID) throws {
        let descriptor = FetchDescriptor<CachedCookLogEntry>(
            predicate: #Predicate { $0.id == id }
        )
        for row in try modelContext.fetch(descriptor) {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    private static func toDomain(_ row: CachedCookLogEntry) -> CookLogEntry {
        CookLogEntry(
            id: row.id,
            recipeID: row.recipeID,
            recipeTitle: row.recipeTitle,
            cookedAt: row.cookedAt,
            note: row.note,
            personalRating: row.personalRating,
            photoLocalID: row.photoLocalID
        )
    }
}
