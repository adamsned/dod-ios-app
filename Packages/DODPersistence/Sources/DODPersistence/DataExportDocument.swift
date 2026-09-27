import DODDomain
import DODSupport
import Foundation

/// The top-level "Export My Data" document (DUT-162 / US) — a single portable,
/// human-inspectable JSON snapshot of everything the app keeps on-device for the
/// user: their saved recipes, cooking journal, shopping list, and profile.
///
/// **Why a dedicated value type (not the storage models directly).** The
/// on-device models are spread across three storage layers (the SwiftData
/// `SyncedSavedRecipe` + `CachedCookLogEntry`, the App-Group-UserDefaults
/// shopping list, and the Keychain profile) and each carries storage-only
/// concerns (CloudKit-clean defaults, aisle-decode fallbacks, keychain
/// accessibility). This document is a stable, self-describing wire shape that
/// every section maps INTO, so the export format is independent of any one
/// model's schema and stays faithfully round-trippable (AC — titles, notes,
/// dates, quantities).
///
/// **Human-inspectable (AC).** Encoded pretty-printed with sorted keys and
/// ISO-8601 dates (see ``DataExportService``), and it carries a ``readme``
/// sentence + a ``schemaVersion`` so someone opening the file in any text
/// editor can tell what it is.
///
/// **Empty categories (AC).** Every section is a plain array (or an optional,
/// for the single profile), so an export with nothing saved still encodes to a
/// valid document with empty sections — never a failure.
public struct DataExportDocument: Codable, Equatable, Sendable {

    /// Bumped when the wire shape changes incompatibly, so a future importer can
    /// branch on it. `1` is the DUT-162 initial format.
    public static let currentSchemaVersion = 1

    /// A short sentence stamped at the top of the file so it is self-describing
    /// when opened in a text editor (AC — documented / labeled).
    public static let readmeText =
        "This file is a personal export of your Dutch Oven Daddy data. "
        + "It includes your saved recipes, cooking journal, shopping list, and profile."

    public var schemaVersion: Int
    public var app: String
    public var readme: String
    public var exportedAt: Date

    public var savedRecipes: [DataExportSavedRecipe]
    public var journalEntries: [DataExportJournalEntry]
    public var shoppingList: [DataExportShoppingListItem]
    public var profile: DataExportProfile?

    public init(
        schemaVersion: Int = DataExportDocument.currentSchemaVersion,
        app: String = "Dutch Oven Daddy",
        readme: String = DataExportDocument.readmeText,
        exportedAt: Date,
        savedRecipes: [DataExportSavedRecipe],
        journalEntries: [DataExportJournalEntry],
        shoppingList: [DataExportShoppingListItem],
        profile: DataExportProfile?
    ) {
        self.schemaVersion = schemaVersion
        self.app = app
        self.readme = readme
        self.exportedAt = exportedAt
        self.savedRecipes = savedRecipes
        self.journalEntries = journalEntries
        self.shoppingList = shoppingList
        self.profile = profile
    }
}

// MARK: - Saved recipes

/// One saved recipe (or saved article) in the export — the same display fields
/// the Saved tab renders, plus the save timestamp.
public struct DataExportSavedRecipe: Codable, Equatable, Sendable {

    public var id: Int
    public var title: String
    public var excerpt: String
    public var canonicalURL: String
    public var heroImageURL: String?
    public var totalSeconds: Int?
    public var publishedAt: Date
    public var savedAt: Date
    public var isArticle: Bool

    public init(
        id: Int,
        title: String,
        excerpt: String,
        canonicalURL: String,
        heroImageURL: String?,
        totalSeconds: Int?,
        publishedAt: Date,
        savedAt: Date,
        isArticle: Bool
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.canonicalURL = canonicalURL
        self.heroImageURL = heroImageURL
        self.totalSeconds = totalSeconds
        self.publishedAt = publishedAt
        self.savedAt = savedAt
        self.isArticle = isArticle
    }

    /// Map a Domain ``Recipe`` + its synced save time into the export shape.
    /// `totalTime` is flattened to whole seconds so the field is a plain
    /// integer in the JSON (human-inspectable) rather than a `Duration`.
    public init(recipe: Recipe, savedAt: Date) {
        self.init(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            canonicalURL: recipe.canonicalURL.absoluteString,
            heroImageURL: recipe.heroImage?.absoluteString,
            totalSeconds: recipe.totalTime.map { Int($0.components.seconds) },
            publishedAt: recipe.publishedAt,
            savedAt: savedAt,
            isArticle: recipe.kind == .article
        )
    }
}

// MARK: - Cooking journal

/// One "I made this" cooking-journal entry in the export (US-48 / DUT-104).
public struct DataExportJournalEntry: Codable, Equatable, Sendable {

    public var id: UUID
    public var recipeID: Int
    public var recipeTitle: String
    public var cookedAt: Date
    public var note: String?
    public var personalRating: Int?
    public var photoLocalID: String?

    public init(
        id: UUID,
        recipeID: Int,
        recipeTitle: String,
        cookedAt: Date,
        note: String?,
        personalRating: Int?,
        photoLocalID: String?
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.cookedAt = cookedAt
        self.note = note
        self.personalRating = personalRating
        self.photoLocalID = photoLocalID
    }

    /// Map the pure ``CookLogEntry`` value type into the export shape.
    public init(entry: CookLogEntry) {
        self.init(
            id: entry.id,
            recipeID: entry.recipeID,
            recipeTitle: entry.recipeTitle,
            cookedAt: entry.cookedAt,
            note: entry.note,
            personalRating: entry.personalRating,
            photoLocalID: entry.photoLocalID
        )
    }
}

// MARK: - Shopping list

/// One shopping-list row in the export (US-39). Mirrors the persisted per-recipe
/// row plus its ephemeral check / already-have state. The aisle is stored as its
/// raw string so the file stays readable and decoupled from the classifier enum.
public struct DataExportShoppingListItem: Codable, Equatable, Sendable {

    public var id: UUID
    public var ingredientText: String
    public var recipeTitle: String
    public var aisle: String
    public var isChecked: Bool
    public var alreadyHave: Bool

    public init(
        id: UUID,
        ingredientText: String,
        recipeTitle: String,
        aisle: String,
        isChecked: Bool,
        alreadyHave: Bool
    ) {
        self.id = id
        self.ingredientText = ingredientText
        self.recipeTitle = recipeTitle
        self.aisle = aisle
        self.isChecked = isChecked
        self.alreadyHave = alreadyHave
    }
}

// MARK: - Profile

/// The on-device user profile in the export (US-44). The photo bytes are NOT
/// inlined; only the on-disk filename is recorded so the JSON stays small and
/// text-only.
public struct DataExportProfile: Codable, Equatable, Sendable {

    public var id: UUID
    public var displayName: String
    public var email: String
    public var photoFilename: String?

    public init(id: UUID, displayName: String, email: String, photoFilename: String?) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoFilename = photoFilename
    }
}
