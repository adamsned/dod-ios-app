import DODDomain
import DODIntelligence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Recipe Detail — Ask Recipe (DUT-1028)")
struct RecipeDetailAskRecipeTests {
    @Test func askAppendsUserAndAssistantMessages() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, recipeAnswer: "Yes.")
        )
        await vm.askRecipe("  Can I freeze it?  ")
        #expect(vm.askMessages.map(\.role) == [.user, .assistant])
        #expect(vm.askMessages.map(\.text) == ["Can I freeze it?", "Yes."])
    }

    @Test func askNilAnswerUsesFallback() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, recipeAnswer: nil)
        )
        await vm.askRecipe("Can I freeze it?")
        #expect(vm.askMessages.last?.text == "I couldn't answer that one. Check the ingredients and steps above.")
    }

    @Test func askNoOpWhenUnavailable() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        await vm.askRecipe("Can I freeze it?")
        #expect(vm.askMessages.isEmpty)
    }

    @Test func toolboxIngredientsAreScaledByServings() {
        let vm = Self.makeViewModel(intelligence: FakeIntelligenceService(isAvailable: true))
        vm.setUserServings(vm.sourceServings * 2)
        let expected = (vm.recipe?.ingredients ?? []).map { FractionRenderer.scale($0.text, by: 2) }
        #expect(vm.makeAskToolbox()?.scaledIngredients == expected)
    }

    static func makeViewModel(intelligence: (any DODIntelligenceService)?) -> RecipeDetailViewModel {
        let vm = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            dependencies: FakeRecipeDetailDependencies(),
            intelligence: intelligence
        )
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)
        return vm
    }
}
