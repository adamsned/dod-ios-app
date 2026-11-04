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

    private static func makeViewModel(
        stepCount: Int,
        spy: SpyNowPlayingPublisher
    ) -> CookModeViewModel {
        let instructions = (1...stepCount).map { RecipeInstruction(step: $0, text: "Step \($0) body.") }
        let recipe = Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: instructions
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier(),
            voiceReader: VoiceReader(synthesizer: MockSpeechSynthesizer()),
            nowPlayingPublisher: spy
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

    @Test func enablingVoiceModeActivatesAndPublishesPlaying() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = Self.makeViewModel(stepCount: 3, spy: spy)
        viewModel.setVoiceMode(true)
        #expect(spy.activateCount == 1)
        #expect(spy.published.last?.state == .playing)
    }

    @Test func pausePublishesPaused() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = Self.makeViewModel(stepCount: 3, spy: spy)
        viewModel.setVoiceMode(true)
        viewModel.pauseVoice()
        #expect(spy.published.last?.state == .paused)
    }

    @Test func resumePublishesPlaying() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = Self.makeViewModel(stepCount: 3, spy: spy)
        viewModel.setVoiceMode(true)
        viewModel.pauseVoice()
        viewModel.resumeVoice()
        #expect(spy.published.last?.state == .playing)
    }

    @Test func advancePublishesNewStepTitle() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = Self.makeViewModel(stepCount: 3, spy: spy)
        viewModel.setVoiceMode(true)
        viewModel.advanceStep()
        #expect(spy.published.last?.title == "Step 2 of \(viewModel.stepCount)")
    }

    @Test func disablingVoiceModeDeactivates() {
        let spy = SpyNowPlayingPublisher()
        let viewModel = Self.makeViewModel(stepCount: 3, spy: spy)
        viewModel.setVoiceMode(true)
        viewModel.setVoiceMode(false)
        #expect(spy.deactivateCount == 1)
    }
}
