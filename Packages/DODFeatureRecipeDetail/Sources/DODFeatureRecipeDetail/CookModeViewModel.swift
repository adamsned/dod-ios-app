import DODAnalytics
import DODCookActivity
import DODDomain
import Foundation
import Observation

#if canImport(UIKit)
import UIKit
#endif

/// Drives Cook Mode (US-7) step navigation and the screen-stay-awake toggle.
/// Kept separate from ``CookModeView`` so the navigation rules, the
/// "finished" terminal state, and the symmetric `isIdleTimerDisabled`
/// behaviour can be unit-tested without booting SwiftUI.
///
/// Telemetry note: this VM does **not** fire `cookModeStarted` itself —
/// the CTA tap site in ``RecipeDetailView`` owns that send so the event
/// matches AC-7.7 "first time Cook Mode is entered for a given recipe
/// during a session" without depending on VM re-instantiation order.
///
/// Spec trace:
/// - AC-7.3 — sets the idle timer on entry, restores prior value on exit.
/// - AC-7.4 — `goNext` clamps at the last step, `goBack` clamps at zero,
///   `isFinished` flips true only after the user advances past the last step.
/// - AC-7.5 — ingredient check state is seeded in and surfaced back out so
///   it round-trips with recipe detail.
/// - AC-7.6 — `endCookMode` restores the idle timer regardless of where the
///   user is in the flow.
@Observable
@MainActor
public final class CookModeViewModel {

    public let recipe: Recipe
    public private(set) var currentStepIndex: Int = 0
    public private(set) var isFinished: Bool = false
    public var checkedIngredientIDs: Set<UUID>

    /// Whether Voice Mode (US-40) is reading steps aloud. **Off** every time
    /// Cook Mode is entered and **not** persisted across sessions — a deliberate
    /// v1 choice (CL-79 / AC-40.1) so the app never starts talking unexpectedly.
    /// `internal(set)` so the Voice Mode methods in `CookModeViewModel+Voice.swift`
    /// can flip it; the public read-only contract is unchanged.
    public internal(set) var isVoiceModeEnabled: Bool = false

    private let idleTimer: any IdleTimerController
    private let liveActivity: any CookLiveActivityController
    /// `internal` (not `private`) so the Voice Mode + pacing methods in
    /// `CookModeViewModel+Voice.swift` can drive the reader from a sibling file.
    let voiceReader: VoiceReader
    private var priorIdleTimerDisabled: Bool = false
    private var didBegin: Bool = false

    /// DUT-293/294 — per-step countdown state owned HERE (not the `CookTimer`
    /// view's `@State`), keyed by step index. This is what lets a running timer
    /// keep counting while you browse other steps, stops one step from showing
    /// another step's countdown, and lets the VM reconcile the Live Activity so
    /// navigating away never strands a ghost card. Mutated by the methods in
    /// `CookModeViewModel+Timers.swift` (hence `internal(set)`).
    public internal(set) var stepTimers: [Int: CookStepTimer] = [:]
    /// Bumped each time a step timer reaches zero so the view can fire the
    /// completion haptic (a changing value, not a Bool).
    public internal(set) var timerCompletionTick: Int = 0
    /// Which step's timer is currently driving the Live Activity card (`nil` =
    /// none). Lets `reconcileLiveActivity` know when to (re)start vs update.
    var liveActivityStepKey: Int?

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        idleTimer: any IdleTimerController = SystemIdleTimerController(),
        liveActivity: any CookLiveActivityController = SystemCookLiveActivityController(),
        voiceReader: VoiceReader = VoiceReader()
    ) {
        self.recipe = recipe
        self.checkedIngredientIDs = initialCheckedIngredients
        self.idleTimer = idleTimer
        self.liveActivity = liveActivity
        self.voiceReader = voiceReader
    }

    /// Total number of steps, derived from the recipe. Zero if the recipe
    /// has no instructions parsed (Cook Mode shouldn't even be presented in
    /// that case — guarded by the entry CTA).
    public var stepCount: Int {
        recipe.instructions.count
    }

    /// The instruction currently being shown to the user.
    public var currentStep: RecipeInstruction? {
        guard currentStepIndex >= 0, currentStepIndex < recipe.instructions.count else {
            return nil
        }
        return recipe.instructions[currentStepIndex]
    }

    /// True when we're on the last step (so the bottom-bar CTA reads
    /// "Done cooking" instead of "Next").
    public var isOnLastStep: Bool {
        currentStepIndex == max(0, recipe.instructions.count - 1)
    }

    /// True after `beginCookMode` and before `endCookMode` — exposed for tests.
    public var isIdleTimerDisabled: Bool {
        idleTimer.isDisabled
    }

    // MARK: - Lifecycle

    /// Called on view appear: captures the prior idle-timer value and sets
    /// it to `true`. Safe to call repeatedly — only the first call has effect.
    public func beginCookMode() {
        guard !didBegin else { return }
        didBegin = true
        priorIdleTimerDisabled = idleTimer.isDisabled
        idleTimer.isDisabled = true
        // Register as the live target for the Voice Mode Siri intents (US-40 /
        // AC-40.5, CL-83). The bus holds us weakly and only ever drives the
        // foreground session; `endCookMode()` clears the registration.
        VoiceCommandBus.shared.handler = self
    }

    /// Called on view disappear: restores the previous idle-timer value
    /// and ends any in-flight Live Activity (AC-11.3). Symmetric with
    /// `beginCookMode` (AC-7.3, AC-7.6).
    public func endCookMode() {
        guard didBegin else { return }
        idleTimer.isDisabled = priorIdleTimerDisabled
        didBegin = false
        // Exiting Cook Mode must clear the Lock Screen card — leaving a
        // ghost activity behind would be the Live Activity equivalent of
        // the "battery still draining" idle-timer bug.
        liveActivity.end()
        // DUT-293/294 — the session's over: drop all step timers + forget which
        // one drove the card, so a re-entry starts clean.
        stepTimers.removeAll()
        liveActivityStepKey = nil
        // AC-7.6 / AC-40.1 — stop any in-flight utterance and release the
        // ducked audio session so the user's music returns to full volume
        // the moment they leave Cook Mode.
        voiceReader.stop()
        isVoiceModeEnabled = false
        // Unregister from the Voice Mode command bus so a Siri command fired
        // after Cook Mode closes is a no-op rather than driving a stale session
        // (US-40 / AC-40.5, CL-83). Guard against clobbering a newer session
        // that may already have registered.
        if VoiceCommandBus.shared.handler === self {
            VoiceCommandBus.shared.handler = nil
        }
    }

    // MARK: - Voice Mode (US-40 / DUT-325)
    //
    // The Voice Mode toggle, the dessert-aware spoken-completion line, the
    // one-shot replay, the session pacing controls, and the AC-40.5 voice-
    // command surface live in `CookModeViewModel+Voice.swift` so this type
    // body stays under the SwiftLint `type_body_length` cap. `goNext`/`goBack`
    // call the (internal) `speakCurrentStep()` declared there.

    // MARK: - Live Activity (US-11)

    /// True while a Live Activity card is on the Lock Screen / Dynamic
    /// Island for the current Cook Mode session. Plumbed through to the
    /// inline ``CookTimer`` so its tick can mirror progress to the system
    /// surface.
    public var hasLiveActivity: Bool {
        liveActivity.isActive
    }

    /// Begin a Live Activity for the supplied countdown. Called by
    /// ``CookTimer`` the moment the user taps Start. Idempotent — a new
    /// start replaces any in-flight activity so the displayed step text
    /// always matches the one driving the countdown.
    public func startTimerLiveActivity(stepText: String, totalSeconds: Int) {
        guard totalSeconds > 0 else { return }
        let attributes = CookActivityAttributes(
            recipeTitle: recipe.title,
            recipeID: recipe.id,
            totalSeconds: totalSeconds
        )
        let initial = CookActivityAttributes.ContentState(
            remainingSeconds: totalSeconds,
            stepText: stepText,
            isPaused: false,
            // DUT-218: the live deadline so the Lock Screen countdown self-ticks
            // (via `Text(timerInterval:)`) even while the app is backgrounded.
            endDate: Date(timeIntervalSinceNow: TimeInterval(totalSeconds))
        )
        liveActivity.start(attributes: attributes, initialState: initial)
    }

    /// Push a new per-second state to the in-flight activity (AC-11.2).
    public func updateTimerLiveActivity(remainingSeconds: Int, stepText: String, isPaused: Bool) {
        guard liveActivity.isActive else { return }
        let state = CookActivityAttributes.ContentState(
            remainingSeconds: max(remainingSeconds, 0),
            stepText: stepText,
            isPaused: isPaused,
            // DUT-218: running → a live deadline (self-ticking countdown);
            // paused → nil so the views show the frozen snapshot.
            endDate: isPaused
                ? nil : Date(timeIntervalSinceNow: TimeInterval(max(remainingSeconds, 0)))
        )
        liveActivity.update(state: state)
    }

    /// End the in-flight activity — called on timer completion, on the
    /// user tapping Reset, and as part of ``endCookMode`` (AC-11.3).
    public func endTimerLiveActivity() {
        liveActivity.end()
    }

    // MARK: - Navigation

    public func goNext() {
        if currentStepIndex < recipe.instructions.count - 1 {
            currentStepIndex += 1
        } else {
            isFinished = true
        }
        // AC-40.3 — re-read whenever the step changes while Voice Mode is on,
        // whether the change came from an on-screen tap, a swipe, or a voice
        // command. A no-op when Voice Mode is off.
        speakCurrentStep()
    }

    public func goBack() {
        if isFinished {
            isFinished = false
        } else if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
        speakCurrentStep()
    }

    // MARK: - Ingredient state

    public func toggleIngredient(_ id: UUID) {
        if checkedIngredientIDs.contains(id) {
            checkedIngredientIDs.remove(id)
        } else {
            checkedIngredientIDs.insert(id)
        }
    }
}

// MARK: - Voice command handler conformance (US-40 / AC-40.5)

/// The four hands-free control methods (declared above for the in-app wiring
/// in T-690b) *are* the ``VoiceCommandHandler`` surface — declaring the
/// conformance lets ``VoiceCommandBus`` forward Siri commands straight into the
/// live session with no adapter (CL-83).
extension CookModeViewModel: VoiceCommandHandler {}

// MARK: - Idle timer abstraction

/// Lets the view model drive `UIApplication.isIdleTimerDisabled` in
/// production while letting tests stub the property with a plain class.
/// Marker-only protocol — the actual production conformance lives in
/// ``SystemIdleTimerController``.
@MainActor
public protocol IdleTimerController: AnyObject {
    var isDisabled: Bool { get set }
}

/// Production conformance — backed by `UIApplication.shared.isIdleTimerDisabled`.
/// On non-UIKit hosts (e.g. swift test on macOS), reads/writes a local
/// boolean so the type still satisfies the protocol.
@MainActor
public final class SystemIdleTimerController: IdleTimerController {

    public init() {}

    public var isDisabled: Bool {
        get {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled
            #else
            localValue
            #endif
        }
        set {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = newValue
            #else
            localValue = newValue
            #endif
        }
    }

    #if !canImport(UIKit)
    private var localValue: Bool = false
    #endif
}
