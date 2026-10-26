import AppIntents
import CoreSpotlight
import DODSupport
import Foundation

/// DUT-1018 — a completed cook (the user's own journal entry) as an App Entity so it joins the Spotlight semantic index. Distinct from ``RecipeEntity``.
struct CookJournalEntryEntity: AppEntity, IndexedEntity {
    let id: UUID
    let recipeID: Int
    let recipeTitle: String
    let cookedAt: Date
    let note: String?
    let photoLocalID: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Cook Journal Entry")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(recipeTitle)",
            subtitle: "\(cookedAt.formatted(date: .abbreviated, time: .omitted))"
        )
    }

    static let defaultQuery = CookJournalEntryEntityQuery()

    init(entry: CookLogEntry) {
        self.id = entry.id
        self.recipeID = entry.recipeID
        self.recipeTitle = entry.recipeTitle
        self.cookedAt = entry.cookedAt
        self.note = entry.note
        self.photoLocalID = entry.photoLocalID
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = "I made \(recipeTitle)"
        set.displayName = recipeTitle
        let dateText = cookedAt.formatted(date: .long, time: .omitted)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        set.contentDescription = trimmed.isEmpty ? "Cooked on \(dateText)" : "\(trimmed) — cooked on \(dateText)"
        set.contentCreationDate = cookedAt
        set.keywords = ["cook journal", "I made this", recipeTitle, dateText]
        return set
    }
}

struct CookJournalEntryEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CookJournalEntryEntity] { [] }
}
