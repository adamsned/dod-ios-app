import AppIntents
import Foundation
import SwiftUI

/// Open a specific recipe's detail screen via Siri / Shortcuts / Spotlight.
///
/// Spec trace: US-10 / AC-10.1, AC-10.2. The intent does not perform any
/// fetch itself — it just nominates a `DeepLinkIntent.openRecipe` URL which
/// `RootView.onOpenURL` then routes into the Feed tab's NavigationStack.
struct OpenRecipeIntent: AppIntent {

    static let title: LocalizedStringResource = "Open Recipe"
    static let description = IntentDescription(
        "Opens a Dutch Oven Daddy recipe by name in the app."
    )

    /// Allow Siri to launch the app on invocation. Without this the intent
    /// can still run but the user has to be in the app already.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        DeepLinkDispatcher.shared.dispatch(.openRecipe(id: recipe.id))
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$recipe)")
    }
}

/// Same as `OpenRecipeIntent` but routes the deep link through Cook Mode
/// so Siri can take the user directly to the hands-free cooking surface.
///
/// Spec trace: US-10 / AC-10.1. RootView.handle(intent:) opens the detail
/// screen and then immediately presents Cook Mode once the recipe is loaded.
struct StartCookModeIntent: AppIntent {

    static let title: LocalizedStringResource = "Start Cook Mode"
    static let description = IntentDescription(
        "Opens a recipe and jumps straight to hands-free Cook Mode."
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        DeepLinkDispatcher.shared.dispatch(.startCookMode(recipeID: recipe.id))
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
                "Open \(\.$recipe) in \(.applicationName)",
                "Show \(\.$recipe) in \(.applicationName)",
                "Find \(\.$recipe) in \(.applicationName)",
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
        // Voice Mode hands-free commands (US-40 / AC-40.5, CL-83). The
        // AppIntents metadata processor requires **every** utterance to contain
        // `\(.applicationName)` (not just phrases that interpolate a
        // `@Parameter`) — it fails the export otherwise. So each phrase suffixes
        // `in \(.applicationName)`, matching the recipe intents above. In
        // practice Siri still matches the bare command once the shortcut is
        // donated; the token is what scopes the phrase to this app.
        AppShortcut(
            intent: NextStepIntent(),
            phrases: [
                "Next step in \(.applicationName)",
                "Next in \(.applicationName)",
                "Go forward in \(.applicationName)",
            ],
            shortTitle: "Next Step",
            systemImageName: "chevron.right"
        )
        AppShortcut(
            intent: PreviousStepIntent(),
            phrases: [
                "Previous step in \(.applicationName)",
                "Go back in \(.applicationName)",
                "Back in \(.applicationName)",
            ],
            shortTitle: "Previous Step",
            systemImageName: "chevron.left"
        )
        AppShortcut(
            intent: RepeatStepIntent(),
            phrases: [
                "Repeat step in \(.applicationName)",
                "Repeat that in \(.applicationName)",
                "Say that again in \(.applicationName)",
            ],
            shortTitle: "Repeat Step",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: PauseVoiceIntent(),
            phrases: [
                "Pause reading in \(.applicationName)",
                "Pause in \(.applicationName)",
            ],
            shortTitle: "Pause Reading",
            systemImageName: "pause.fill"
        )
    }
}
