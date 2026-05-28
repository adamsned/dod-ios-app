import DODAnalytics
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
    public private(set) var isVoiceModeEnabled: Bool = false

    private let idleTimer: any IdleTimerController
    private let liveActivity: any CookLiveActivityController
    private let voiceReader: VoiceReader
    private var priorIdleTimerDisabled: Bool = false
    private var didBegin: Bool = false

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
        // AC-40.5, CL-82). The bus holds us weakly and only ever drives the
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
        // AC-7.6 / AC-40.1 — stop any in-flight utterance and release the
        // ducked audio session so the user's music returns to full volume
        // the moment they leave Cook Mode.
        voiceReader.stop()
        isVoiceModeEnabled = false
        // Unregister from the Voice Mode command bus so a Siri command fired
        // after Cook Mode closes is a no-op rather than driving a stale session
        // (US-40 / AC-40.5, CL-82). Guard against clobbering a newer session
        // that may already have registered.
        if VoiceCommandBus.shared.handler === self {
            VoiceCommandBus.shared.handler = nil
        }
    }

    // MARK: - Voice Mode (US-40)

    /// Flip Voice Mode on or off (AC-40.1). Turning it **on** immediately reads
    /// the current step (AC-40.2); turning it **off** stops reading and releases
    /// the audio session. Idempotent — setting the same value re-reads the
    /// current step (on) or is a no-op (off).
    public func setVoiceMode(_ enabled: Bool) {
        let changed = isVoiceModeEnabled != enabled
        isVoiceModeEnabled = enabled
        if enabled {
            speakCurrentStep()
        } else {
            voiceReader.stop()
        }
        // AC-40.8 / CL-82 — report the user-driven on/off as an allowlisted
        // device-state event. Payload is a single boolean — no recipe id, no
        // free text. Only fire on an actual flip so an idempotent re-set (which
        // re-reads the current step) doesn't double-count.
        if changed {
            Telemetry.shared.send(.voiceModeToggled(on: enabled))
        }
    }

    /// Convenience for the on-screen toggle button (AC-40.1).
    public func toggleVoiceMode() {
        setVoiceMode(!isVoiceModeEnabled)
    }

    /// Re-speak the current step (or the completion line in the Done state).
    /// Drives AC-40.3's re-read-on-step-change behaviour and AC-40.5's
    /// "repeat" command. A no-op while Voice Mode is off so navigation never
    /// makes noise the user didn't ask for. Because ``VoiceReader/speak(_:)``
    /// stops any in-flight utterance first (AC-40.7), advancing several steps
    /// quickly never overlaps two voices.
    private func speakCurrentStep() {
        guard isVoiceModeEnabled else { return }
        if isFinished {
            // AC-40.3 — reaching Done speaks a short completion line rather
            // than a step body.
            voiceReader.speak("All done — enjoy your meal")
        } else if let step = currentStep {
            voiceReader.speak(step.text)
        }
    }

    // MARK: - Voice command surface (US-40 / AC-40.5)
    //
    // The four methods below are the in-app control surface the T-690c App
    // Intents will call to drive Cook Mode hands-free via Siri. They are wired
    // here (and exercised in-app + by L1 tests) in T-690b; T-690c only exposes
    // them to SiriKit. Each re-reads through the same AC-40.3 path so a voice
    // command and an on-screen tap behave identically.

    /// "Next step" — advance one step and re-read it when Voice Mode is on.
    /// Same path as the on-screen Next control (AC-7.4 / AC-40.5).
    public func advanceStep() {
        goNext()
    }

    /// "Previous step" / "go back" — step back one and re-read it when Voice
    /// Mode is on. Same path as the on-screen Previous control (AC-40.5).
    public func previousStep() {
        goBack()
    }

    /// "Repeat that" — re-speak the current step without changing position
    /// (AC-40.5). Implicitly interrupts any paused utterance via the reader's
    /// stop-before-speak contract (AC-40.7).
    public func repeatCurrentStep() {
        speakCurrentStep()
    }

    /// "Pause" — pause the current utterance at the next word boundary
    /// (AC-40.4 / AC-40.5). Leaves Voice Mode on so a subsequent navigation or
    /// "repeat" command resumes reading aloud.
    public func pauseVoice() {
        voiceReader.pause()
    }

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
            isPaused: false
        )
        liveActivity.start(attributes: attributes, initialState: initial)
    }

    /// Push a new per-second state to the in-flight activity (AC-11.2).
    public func updateTimerLiveActivity(remainingSeconds: Int, stepText: String, isPaused: Bool) {
        guard liveActivity.isActive else { return }
        let state = CookActivityAttributes.ContentState(
            remainingSeconds: max(remainingSeconds, 0),
            stepText: stepText,
            isPaused: isPaused
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
/// live session with no adapter (CL-82).
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
