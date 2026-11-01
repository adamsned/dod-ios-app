import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
final class SpyNowPlayingPublisher: NowPlayingPublishing {
    var activateCount = 0
    var published: [NowPlayingSnapshot] = []
    var deactivateCount = 0

    func activate(onCommand: @escaping @MainActor (NowPlayingRemoteCommand) -> Void) {
        activateCount += 1
    }

    func publish(_ snapshot: NowPlayingSnapshot) {
        published.append(snapshot)
    }

    func deactivate() {
        deactivateCount += 1
    }
}

@MainActor
@Suite("CookModeViewModel Now Playing lifecycle (DUT-1012)") struct CookModeNowPlayingLifecycleTests {
    private static func makeRecipe() -> Recipe {
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

    @Test func endCookModeDeactivatesPublisher() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = CookModeViewModel(
            recipe: Self.makeRecipe(),
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier(),
            nowPlayingPublisher: spy
        )
        viewModel.beginCookMode()
        viewModel.endCookMode()
        #expect(spy.deactivateCount == 1)
    }

    @Test func nilPublisherIsHarmless() {
        let viewModel = CookModeViewModel(
            recipe: Self.makeRecipe(),
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier()
        )
        viewModel.beginCookMode()
        viewModel.endCookMode()
        #expect(viewModel.nowPlayingPublisher == nil)
    }
}
