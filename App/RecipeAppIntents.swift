import AppIntents
import Foundation
import SwiftUI

/// Open a specific recipe's detail screen via Siri / Shortcuts / Spotlight.
///
/// Spec trace: US-10 / AC-10.1, AC-10.2. The intent does not perform any
/// fetch itself — it just nominates a `DeepLinkIntent.openRecipe` URL which
/// `RootView.onOpenURL` then routes into the Feed tab's NavigationStack.
///
/// DUT-1388 — an `OpenIntent` (parameter `target`), which makes it THE "open
/// this recipe" action for a ``RecipeEntity``: tapping a recipe in Spotlight's
/// entity results or in a Siri result list (e.g. Find Recipes) runs it.
struct OpenRecipeIntent: OpenIntent {

    static let title: LocalizedStringResource = "Open Recipe"
    static let description = IntentDescription(
        "Opens a Dutch Oven Daddy recipe by name in the app."
    )

    /// Allow Siri to launch the app on invocation. Without this the intent
    /// can still run but the user has to be in the app already.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recipe")
    var target: RecipeEntity

    init() {}

    init(target: RecipeEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        DeepLinkDispatcher.shared.dispatch(.openRecipe(id: target.id))
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }
}

/// Same as `OpenRecipeIntent` but routes the deep link through Cook Mode
/// so Siri can take the user directly to the hands-free cooking surface.
///
/// Spec trace: US-10 / AC-10.1. RootView.handle(intent:) opens the detail
/// screen and then immediately presents Cook Mode once the recipe is loaded.
///
/// DUT-1388 — the recipe is optional: "Start cook mode in Dutch Oven Daddy"
/// while a recipe is open cooks THAT one (``OnscreenRecipe``); with nothing
/// open, Siri asks which recipe.
struct StartCookModeIntent: AppIntent {

    static let title: LocalizedStringResource = "Start Cook Mode"
    static let description = IntentDescription(
        "Opens a recipe and jumps straight to hands-free Cook Mode."
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity?

    init() {}

    init(recipe: RecipeEntity) {
        self.recipe = recipe
    }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let resolved = OnscreenRecipe.resolve(recipe) else {
            throw $recipe.needsValueError("Which recipe do you want to cook?")
        }
        DeepLinkDispatcher.shared.dispatch(.startCookMode(recipeID: resolved.id))
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start Cook Mode for \(\.$recipe)")
    }
}

/// Switch the app to the Saved tab. Useful as a one-tap Shortcut /
/// Spotlight result for "my saved recipes".
///
/// Spec trace: US-10 / AC-10.1.
struct OpenSavedRecipesIntent: AppIntent {

    static let title: LocalizedStringResource = "Show Saved Recipes"
    static let description = IntentDescription(
        "Opens the list of recipes you've saved."
    )

    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        DeepLinkDispatcher.shared.dispatch(.openSaved)
        return .result()
    }
}

/// Registers all three intents with the system so they show up in Spotlight,
/// Siri, and the Shortcuts app without the user having to add them manually.
///
/// Spec trace: US-10 / AC-10.4. The `appShortcuts` static is read by the
/// system on first app launch (and after every app upgrade) and the phrases
/// here are what Siri matches against.
///
/// Per Apple's AppIntents iOS 17 guidance, phrases referencing a parameter
/// MUST contain `\(.applicationName)` somewhere — the framework rejects the
/// build at runtime otherwise. We use the trailing form so the verb reads
/// naturally aloud.
struct DODShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                // DUT-405: dropped the greedy "Show \(recipe)" template — it captured
                // "Show my saved recipes" (recipe = "my saved recipes") and dead-ended
                // instead of letting OpenSavedRecipesIntent's literal phrase win.
                "Open \(\.$target) in \(.applicationName)",
                "Find \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Recipe",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: StartCookModeIntent(),
            phrases: [
                "Start cooking \(\.$recipe) in \(.applicationName)",
                "Cook \(\.$recipe) in \(.applicationName)",
                "Start cook mode for \(\.$recipe) in \(.applicationName)",
                // DUT-1388 — no recipe named: cooks the one on screen.
                "Start cook mode in \(.applicationName)",
                "Cook this in \(.applicationName)",
                "Start cooking this in \(.applicationName)",
            ],
            shortTitle: "Start Cook Mode",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: OpenSavedRecipesIntent(),
            phrases: [
                "Show my saved recipes in \(.applicationName)",
                "Open saved recipes in \(.applicationName)",
            ],
            shortTitle: "Saved Recipes",
            systemImageName: "bookmark.fill"
        )
        // DUT-1388 — Find / Save / Add to Shopping List / Open Collection. A
        // String parameter can't sit in a phrase, so Find asks "What recipe are
        // you looking for?". Save + Add without a named recipe act on the one
        // on screen (`OnscreenRecipe`).
        AppShortcut(
            intent: FindRecipesIntent(),
            phrases: [
                "Find a recipe in \(.applicationName)",
                "Search \(.applicationName)",
                "Search for a recipe in \(.applicationName)",
            ],
            shortTitle: "Find Recipes",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: SaveRecipeIntent(),
            phrases: [
                "Save \(\.$recipe) in \(.applicationName)",
                "Save this recipe in \(.applicationName)",
                "Save this in \(.applicationName)",
            ],
            shortTitle: "Save Recipe",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: AddRecipeToShoppingListIntent(),
            phrases: [
                "Add \(\.$recipe) to my shopping list in \(.applicationName)",
                "Add this recipe to my shopping list in \(.applicationName)",
                "Add the ingredients to my shopping list in \(.applicationName)",
            ],
            shortTitle: "Add to Shopping List",
            systemImageName: "cart.badge.plus"
        )
        AppShortcut(
            intent: OpenCollectionIntent(),
            phrases: [
                "Open my \(\.$target) collection in \(.applicationName)",
                "Show my \(\.$target) collection in \(.applicationName)",
                "Show my collections in \(.applicationName)",
            ],
            shortTitle: "Open Collection",
            systemImageName: "folder"
        )
        // Voice Mode hands-free commands (US-40 / AC-40.5, CL-83). The
        // AppIntents metadata processor requires **every** utterance to contain
        // `\(.applicationName)` (not just phrases that interpolate a
        // `@Parameter`) — it fails the export otherwise. DUT-1388 — the five
        // commands now share ONE App Shortcut (Apple's cap is 10 per app); the
        // `CookModeCommandOption` case titles + synonyms expand this phrase into
        // the same utterances the five separate shortcuts had ("Next step in",
        // "Go back in", "Say that again in", "Pause in", "Continue reading in").
        AppShortcut(
            intent: CookModeCommandIntent(),
            phrases: [
                "\(\.$command) in \(.applicationName)"
            ],
            shortTitle: "Cook Mode Commands",
            systemImageName: "waveform"
        )
    }
}
