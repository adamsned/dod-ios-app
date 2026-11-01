import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-981 — `CookModeView` carries an optional guest-reaction sink.
@MainActor
@Suite("Cook Mode guest reaction wiring (DUT-981)")
struct CookModeGuestReactionWiringTests {

    private var recipe: Recipe {
        Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: [RecipeInstruction(step: 1, text: "Step 1 body.")]
        )
    }

    @Test func sinkIsNilByDefault() {
        let view = CookModeView(recipe: recipe, initialCheckedIngredients: [], onClose: { _ in })
        #expect(view.onPostGuestReaction == nil)
    }

    @Test func sinkIsStoredWhenProvided() {
        let view = CookModeView(
            recipe: recipe,
            initialCheckedIngredients: [],
            onClose: { _ in },
            onPostGuestReaction: { _, _, _ in true }
        )
        #expect(view.onPostGuestReaction != nil)
    }
}
