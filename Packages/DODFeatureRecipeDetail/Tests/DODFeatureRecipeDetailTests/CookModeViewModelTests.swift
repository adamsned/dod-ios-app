import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel (US-7 + US-11)") struct CookModeViewModelTests {

    // MARK: - Navigation (AC-7.4)

    @Test func nextAdvancesOneStepAtATime() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        #expect(viewModel.currentStepIndex == 0)
        viewModel.goNext()
        #expect(viewModel.currentStepIndex == 1)
        viewModel.goNext()
        #expect(viewModel.currentStepIndex == 2)
    }

    @Test func previousReversesOneStep() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        viewModel.goNext()
        viewModel.goNext()
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 1)
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 0)
    }

    @Test func previousAtFirstStepIsAnInertNoOp() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        viewModel.goBack()
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 0)
        #expect(!viewModel.isFinished)
    }

    @Test func nextOnLastStepFlipsToFinished() {
        let viewModel = Self.makeViewModel(stepCount: 2)
        viewModel.goNext()
        #expect(viewModel.isOnLastStep)
        #expect(!viewModel.isFinished)
        viewModel.goNext()
        // AC-7.4 — "Done" state, no auto-loop back to step 1.
        #expect(viewModel.isFinished)
        #expect(viewModel.currentStepIndex == 1, "Index should stay on last step")
    }

    @Test func backOutOfDoneReturnsToLastStep() {
        let viewModel = Self.makeViewModel(stepCount: 2)
        viewModel.goNext()
        viewModel.goNext()
        #expect(viewModel.isFinished)
        viewModel.goBack()
        #expect(!viewModel.isFinished)
        #expect(viewModel.currentStepIndex == 1)
    }

    @Test func singleStepRecipeImmediatelyOnLastStep() {
        let viewModel = Self.makeViewModel(stepCount: 1)
        #expect(viewModel.isOnLastStep)
        viewModel.goNext()
        #expect(viewModel.isFinished)
    }

    // MARK: - Ingredient state (AC-7.5)

    @Test func seedingIngredientsCarriesThroughInitialState() {
        let id1 = UUID()
        let id2 = UUID()
        let viewModel = Self.makeViewModel(stepCount: 1, seed: [id1, id2])
        #expect(viewModel.checkedIngredientIDs == [id1, id2])
    }

    @Test func toggleIngredientAddsAndRemoves() {
        let id = UUID()
        let viewModel = Self.makeViewModel(stepCount: 1)
        viewModel.toggleIngredient(id)
        #expect(viewModel.checkedIngredientIDs.contains(id))
        viewModel.toggleIngredient(id)
        #expect(!viewModel.checkedIngredientIDs.contains(id))
    }

    // MARK: - Idle timer (AC-7.3, AC-7.6)

    @Test func beginCookModeDisablesIdleTimer() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        #expect(!idleTimer.isDisabled)
        viewModel.beginCookMode()
        #expect(idleTimer.isDisabled, "AC-7.3 — screen-stay-awake must be on")
    }

    @Test func endCookModeRestoresPriorIdleTimerValue() {
        let idleTimer = FakeIdleTimerController()
        idleTimer.isDisabled = false  // baseline
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        #expect(idleTimer.isDisabled)
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled, "AC-7.3 — exit must restore prior value")
    }

    @Test func beginAndEndAreSymmetricAcrossReEntries() {
        // Re-entering Cook Mode after a clean exit must leave the device
        // back in its starting state — guards against the "battery still
        // draining hours later" bug.
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        viewModel.endCookMode()
        viewModel.beginCookMode()
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled)
    }

    @Test func beginIsIdempotent() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        viewModel.beginCookMode()
        viewModel.beginCookMode()
        // Repeated begin must not clobber the captured "prior" value —
        // otherwise endCookMode would leave the device with isDisabled=true
        // for the second begin/end pair.
        #expect(idleTimer.isDisabled)
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled, "Prior value should still be the original baseline")
    }

    @Test func endWithoutBeginIsANoOp() {
        // The view's .onDisappear can fire without .onAppear in some
        // SwiftUI lifecycle paths; the toggle must not corrupt prior state.
        let idleTimer = FakeIdleTimerController()
        idleTimer.isDisabled = true  // some other surface had it on
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.endCookMode()
        #expect(idleTimer.isDisabled, "endCookMode without begin must not change anything")
    }

    @Test func isIdleTimerDisabledProxiesUnderlyingController() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        #expect(viewModel.isIdleTimerDisabled == false)
        viewModel.beginCookMode()
        #expect(viewModel.isIdleTimerDisabled == true)
    }

    // MARK: - Live Activity (US-11)

    @Test func startingTimerActivityTogglesHasLiveActivity() {
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        #expect(!viewModel.hasLiveActivity, "AC-11.1 — no activity until the timer starts")
        viewModel.startTimerLiveActivity(stepText: "Bake 30 minutes", totalSeconds: 30 * 60)
        #expect(viewModel.hasLiveActivity, "AC-11.1 — timer-start must create an Activity")
        #expect(activity.startedAttributes?.recipeID == 100)
        #expect(activity.startedAttributes?.totalSeconds == 30 * 60)
        #expect(activity.lastInitialState?.remainingSeconds == 30 * 60)
        #expect(activity.lastInitialState?.isPaused == false)
    }

    @Test func startingZeroDurationTimerIsANoOp() {
        // Defensive: a malformed parse shouldn't spawn an instantly-stale
        // Lock Screen card.
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.startTimerLiveActivity(stepText: "no duration", totalSeconds: 0)
        #expect(activity.startCallCount == 0)
        #expect(!viewModel.hasLiveActivity)
    }

    @Test func endingTimerActivityClearsHasLiveActivity() {
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.startTimerLiveActivity(stepText: "Step", totalSeconds: 60)
        viewModel.endTimerLiveActivity()
        #expect(!viewModel.hasLiveActivity, "AC-11.3 — completion / cancel ends the activity")
        #expect(activity.endCallCount == 1)
    }

    @Test func updatingActivityForwardsContentState() {
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.startTimerLiveActivity(stepText: "Step", totalSeconds: 60)
        viewModel.updateTimerLiveActivity(remainingSeconds: 42, stepText: "Step", isPaused: false)
        #expect(activity.lastUpdateState?.remainingSeconds == 42, "AC-11.2 — per-tick updates flow through")
        #expect(activity.lastUpdateState?.isPaused == false)
    }

    @Test func runningUpdateSetsALiveDeadlineAndPausedClearsIt() {
        // DUT-218: a running tick carries an `endDate` so the Lock Screen
        // countdown self-ticks (`Text(timerInterval:)`) even while backgrounded;
        // pausing clears it so the views show the frozen snapshot instead.
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.startTimerLiveActivity(stepText: "Step", totalSeconds: 60)

        viewModel.updateTimerLiveActivity(remainingSeconds: 42, stepText: "Step", isPaused: false)
        #expect(activity.lastUpdateState?.endDate != nil, "running → a live deadline")

        viewModel.updateTimerLiveActivity(remainingSeconds: 42, stepText: "Step", isPaused: true)
        #expect(activity.lastUpdateState?.endDate == nil, "paused → no deadline (frozen snapshot)")
    }

    @Test func updatingWithoutAnActiveActivityIsANoOp() {
        // Tick events fire from the SwiftUI Timer publisher every second
        // even when no activity is in flight — the VM must filter so we
        // don't churn the system trying to update a dead handle.
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.updateTimerLiveActivity(remainingSeconds: 1, stepText: "x", isPaused: false)
        #expect(activity.updateCallCount == 0)
    }

    @Test func endCookModeAlsoEndsAnyInFlightActivity() {
        // AC-11.3 — Cook Mode exit while a timer is still running must
        // clear the Lock Screen card. Symmetric to the idle-timer toggle.
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.beginCookMode()
        viewModel.startTimerLiveActivity(stepText: "Step", totalSeconds: 60)
        #expect(viewModel.hasLiveActivity)
        viewModel.endCookMode()
        #expect(!viewModel.hasLiveActivity)
        #expect(activity.endCallCount == 1)
    }

    @Test func startingASecondTimerReplacesTheFirst() {
        // Moving forward to a new step while the previous step's timer is
        // still up must not stack two cards.
        let activity = FakeLiveActivityController()
        let viewModel = Self.makeViewModel(stepCount: 1, liveActivity: activity)
        viewModel.startTimerLiveActivity(stepText: "First", totalSeconds: 60)
        viewModel.startTimerLiveActivity(stepText: "Second", totalSeconds: 30)
        #expect(activity.startCallCount == 2)
        #expect(activity.lastInitialState?.stepText == "Second")
        #expect(activity.lastInitialState?.remainingSeconds == 30)
    }

    // MARK: - Helpers

    static func makeViewModel(
        stepCount: Int,
        seed: Set<UUID> = [],
        idleTimer: IdleTimerController = FakeIdleTimerController(),
        liveActivity: any CookLiveActivityController = FakeLiveActivityController(),
        voiceReader: VoiceReader = VoiceReader()
    ) -> CookModeViewModel {
        let instructions = (1...max(stepCount, 1)).map { index in
            RecipeInstruction(step: index, text: "Step \(index) body.")
        }
        let recipe = Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: stepCount > 0 ? instructions : []
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: seed,
            idleTimer: idleTimer,
            liveActivity: liveActivity,
            voiceReader: voiceReader
        )
    }
}

@MainActor
final class FakeIdleTimerController: IdleTimerController {
    var isDisabled: Bool = false
}

/// In-memory fake for ``CookLiveActivityController``. Tracks each side
/// effect so tests can assert on call counts and the most recent
/// attributes / content state without spinning up ActivityKit.
@MainActor
final class FakeLiveActivityController: CookLiveActivityController {

    private(set) var isActive: Bool = false
    private(set) var startCallCount: Int = 0
    private(set) var updateCallCount: Int = 0
    private(set) var endCallCount: Int = 0
    private(set) var startedAttributes: CookActivityAttributes?
    private(set) var lastInitialState: CookActivityAttributes.ContentState?
    private(set) var lastUpdateState: CookActivityAttributes.ContentState?

    func start(
        attributes: CookActivityAttributes,
        initialState: CookActivityAttributes.ContentState
    ) {
        startCallCount += 1
        startedAttributes = attributes
        lastInitialState = initialState
        isActive = true
    }

    func update(state: CookActivityAttributes.ContentState) {
        guard isActive else { return }
        updateCallCount += 1
        lastUpdateState = state
    }

    func end() {
        endCallCount += 1
        isActive = false
    }
}
