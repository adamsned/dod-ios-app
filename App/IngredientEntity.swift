import AppIntents
import DODFeatureRecipeDetail
import Foundation

/// DUT-1014: one ingredient row visible in Recipe Detail, so Siri can name what "that" refers to.
struct IngredientEntity: AppEntity {

    let id: UUID
    let text: String
    let recipeTitle: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Ingredient")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(text)", subtitle: "\(recipeTitle)")
    }

    static let defaultQuery = IngredientEntityQuery()

    init(entry: OnscreenIngredients.Entry) {
        self.id = entry.id
        self.text = entry.displayText
        self.recipeTitle = entry.recipeTitle
    }
}

struct IngredientEntityQuery: EntityQuery, EntityStringQuery {

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [IngredientEntity] {
        OnscreenIngredients.shared.entries
            .filter { identifiers.contains($0.id) }
            .map(IngredientEntity.init(entry:))
    }

    @MainActor
    func suggestedEntities() async throws -> [IngredientEntity] {
        OnscreenIngredients.shared.entries.map(IngredientEntity.init(entry:))
    }

    @MainActor
    func entities(matching string: String) async throws -> [IngredientEntity] {
        OnscreenIngredients.shared.entries
            .filter { $0.displayText.localizedCaseInsensitiveContains(string) }
            .map(IngredientEntity.init(entry:))
    }
}
