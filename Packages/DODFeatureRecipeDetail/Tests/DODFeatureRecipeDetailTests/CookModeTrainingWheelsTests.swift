import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor @Suite struct CookModeTrainingWheelsTests {
    private func makeViewModel() -> CookModeViewModel {
        let recipe = Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: [
                RecipeInstruction(step: 1, text: "Arrange the coals in a ring."),
                RecipeInstruction(step: 2, text: "Stir in the flour."),
            ]
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier(),
            voiceReader: VoiceReader(),
            donenessCoach: DonenessCoach(intelligence: nil)
        )
    }

    @Test func noteNilByDefault() {
        #expect(makeViewModel().trainingWheelsNote == nil)
    }

    @Test func noteShownOnHeatStepWhenFirstCook() {
        let vm = makeViewModel()
        vm.isFirstCookEver = true
        #expect(vm.trainingWheelsNote?.kind == .heatSetup)
    }

    @Test func noteHiddenOnPlainStep() {
        let vm = makeViewModel()
        vm.isFirstCookEver = true
        vm.goNext()
        #expect(vm.trainingWheelsNote == nil)
    }

    @Test func noteClearsAfterFlagFlipsOff() {
        let vm = makeViewModel()
        vm.isFirstCookEver = true
        vm.isFirstCookEver = false
        #expect(vm.trainingWheelsNote == nil)
    }
}
