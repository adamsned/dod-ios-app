import AppIntents
import DODDomain
import DODSupport
import Foundation

// DUT-1388 — the Siri / Shortcuts recipe ACTIONS (Find, Save, Add to Shopping
// List). Unlike the navigation intents in `RecipeAppIntents.swift`, these run
// in the background and answer with a dialog. Save and Add take an optional
// recipe and fall back to the one on screen (``OnscreenRecipe``), so "Save this
// recipe in Dutch Oven Daddy" works while a recipe is open.
//
// No em dashes in any dialog copy (it's user-facing).

/// Search the whole site by recipe name. Returns the matches as entities, so
/// Siri lists them (tapping one runs ``OpenRecipeIntent``) and a Shortcut can
/// chain them.
struct FindRecipesIntent: AppIntent {

    static let title: LocalizedStringResource = "Find Recipes"
    static let description = IntentDescription(
        "Searches Dutch Oven Daddy recipes by name."
    )

    @Parameter(title: "Search", requestValueDialog: "What recipe are you looking for?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Find recipes matching \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[RecipeEntity]> & ProvidesDialog {
        let results = await RecipeEntityQuery.searchPayloads(query: query).map(RecipeEntity.init(payload:))
        return .result(value: results, dialog: Self.dialog(count: results.count, query: query))
    }

    /// Pure dialog copy (unit-tested).
    static func dialog(count: Int, query: String) -> IntentDialog {
        IntentDialog(stringLiteral: dialogText(count: count, query: query))
    }

    static func dialogText(count: Int, query: String) -> String {
        switch count {
        case 0: "I couldn't find a recipe matching \"\(query)\"."
        case 1: "Here's the recipe I found for \"\(query)\"."
        default: "Here are \(count) recipes for \"\(query)\"."
        }
    }
}

/// Save a recipe to the Saved tab (the same path as a card long-press save).
struct SaveRecipeIntent: AppIntent {

    static let title: LocalizedStringResource = "Save Recipe"
    static let description = IntentDescription(
        "Saves a recipe to your Saved recipes, or the recipe you're looking at."
    )

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$recipe)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let target = OnscreenRecipe.resolve(recipe) else {
            throw $recipe.needsValueError("Which recipe do you want to save?")
        }
        guard let store = AppIntentEnvironment.store, let actions = AppIntentEnvironment.actions else {
            throw RecipeActionError.notReady
        }
        if (try? await store.isSaved(id: target.id)) == true {
            return .result(dialog: "\(target.title) is already in your saved recipes.")
        }
        guard await actions.save(target.payload.toListItem()) else { throw RecipeActionError.saveFailed }
        // An open copy of this recipe refreshes its bookmark (not a stale tap).
        NotificationCenter.default.post(name: .dodSavedSetDidChange, object: target.id)
        return .result(dialog: "Saved \(target.title).")
    }
}

/// Add a recipe's ingredients to the Shopping List.
struct AddRecipeToShoppingListIntent: AppIntent {

    static let title: LocalizedStringResource = "Add Ingredients to Shopping List"
    static let description = IntentDescription(
        "Adds a recipe's ingredients to your Shopping List."
    )

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add the ingredients for \(\.$recipe) to the Shopping List")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let target = OnscreenRecipe.resolve(recipe) else {
            throw $recipe.needsValueError("Which recipe's ingredients do you want to add?")
        }
        guard let actions = AppIntentEnvironment.actions else { throw RecipeActionError.notReady }
        // The cached recipe carries parsed ingredients when it was opened here;
        // otherwise the appender fetches + parses them (its hydrate step).
        let cached = try? await AppIntentEnvironment.store?.recipeWithoutTouching(id: target.id)
        let source = cached ?? Recipe(listItem: target.payload.toListItem())
        let result = await actions.addToShoppingList(source)
        return .result(dialog: IntentDialog(stringLiteral: Self.dialogText(result, title: target.title)))
    }

    /// Pure dialog copy (unit-tested).
    static func dialogText(_ result: AddToShoppingListResult, title: String) -> String {
        switch result {
        case .added(let count) where count == 1:
            "Added 1 ingredient from \(title) to your Shopping List."
        case .added(let count):
            "Added \(count) ingredients from \(title) to your Shopping List."
        case .couldntLoad:
            "I couldn't load the ingredients for \(title). Open the recipe and try again."
        }
    }
}

/// Failures the action intents surface to Siri as a spoken error.
enum RecipeActionError: Error, CustomLocalizedStringResourceConvertible {
    /// Fired before the app finished launching (no store / actions yet).
    case notReady
    case saveFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady: "Dutch Oven Daddy is still starting up. Try again in a moment."
        case .saveFailed: "Couldn't save that recipe. Please try again."
        }
    }
}
