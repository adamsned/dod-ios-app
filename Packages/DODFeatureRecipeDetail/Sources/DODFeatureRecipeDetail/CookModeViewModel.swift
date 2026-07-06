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

    /// DUT-583 — the voice player's transport state, driving the center
    /// play/pause button like a podcast player. `.idle` and `.paused` show a
    /// play glyph (nothing reading / resumable), `.speaking` shows pause.
    /// Maintained by the Voice methods in `CookModeViewModel+Voice.swift`;
    /// `internal(set)` so those siblings can flip it. Reset to `.idle` when a
    /// step finishes reading on its own (via the reader's finish callback) or
    /// when Cook Mode ends.
    public enum VoicePlaybackState: Sendable { case idle, speaking, paused }

    /// DUT-583 — current transport state for the center play/pause button.
    public internal(set) var playbackState: VoicePlaybackState = .idle

    /// DUT-583 — the current voice speed as a multiplier of the natural 1×
    /// rate, always one of ``VoiceReader/speedMultipliers``. Session-only; not
    /// persisted (resets to 1× each Cook Mode entry, like Voice Mode itself).
    public internal(set) var voiceSpeedMultiplier: Double = 1.0

    private let idleTimer: any IdleTimerController
    private let liveActivity: any CookLiveActivityController
    /// DUT-604 — schedules the "step timer done" local notification so a
    /// backgrounded step timer still alerts (the in-app buzzer only fires on the
    /// foreground tick). `internal` so the `+Timers` extension drives it.
    let stepTimerNotifier: any CookStepTimerNotifying
    /// `internal` (not `private`) so the Voice Mode + pacing methods in
    /// `CookModeViewModel+Voice.swift` can drive the reader from a sibling file.
    let voiceReader: VoiceReader
    /// DUT-328 — the device language (captured at init, matching the reader's
    /// default locale), for the "get a better voice" natural-voice check.
    /// Internal (not private) so the `+Voice` extension can read it.
    let voiceLanguageCode: String?
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
    /// DUT-354: true once the finished-timer "buzzer" card has been pushed, so
    /// the per-tick reconcile doesn't re-push the frozen 0:00 state every second
    /// while it lingers. Cleared when a running timer takes the card over or the
    /// activity ends.
    var liveActivityShowingCompleted = false
    /// DUT-558: latched true once a `startTimerLiveActivity` attempt fails while
    /// the controller reports Live Activities are unavailable (disabled in
    /// Settings / over quota). While set, `reconcileLiveActivity` stops
    /// re-attempting the start every ~1s tick (DUT-492 kept retrying forever).
    /// Recheck on scene-activate via `revalidateLiveActivityAvailability()`.
    var liveActivityUnavailable = false

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        idleTimer: any IdleTimerController = SystemIdleTimerController(),
        liveActivity: any CookLiveActivityController = SystemCookLiveActivityController(),
        stepTimerNotifier: any CookStepTimerNotifying = SystemCookStepTimerNotifier(),
        voiceReader: VoiceReader = VoiceReader(),
        locale: Locale = .current
    ) {
        self.recipe = recipe
        self.checkedIngredientIDs = initialCheckedIngredients
        self.idleTimer = idleTimer
        self.liveActivity = liveActivity
        self.stepTimerNotifier = stepTimerNotifier
        self.voiceReader = voiceReader
        self.voiceLanguageCode = locale.language.languageCode?.identifier
        // DUT-583 — when a step finishes reading on its own, drop the play/pause
        // button back to the idle "play" glyph. Guard on `.speaking` so a stale
        // drain callback can't stomp a `.paused` state the user just set.
        voiceReader.onDidFinishSpeaking = { [weak self] in
            guard let self, self.playbackState == .speaking else { return }
            self.playbackState = .idle
        }
        // DUT-595 — an audio interruption (call / Siri / timer alarm) ended
        // WITHOUT `.shouldResume`, so the reader left playback parked and iOS
        // cancelled the in-flight utterance. Drop the transport to idle so its
        // glyph shows "play" (not a stuck "pause"), a single tap does a fresh
        // `speakCurrentStep()` (not a no-op `pauseVoice()`), and VoiceOver stops
        // mis-reporting "playing." Guard on `.speaking` so a stale callback
        // can't stomp a `.paused`/idle state the user just set.
        voiceReader.onDidPauseForInterruption = { [weak self] in
            guard let self, self.playbackState == .speaking else { return }
            self.playbackState = .idle
        }
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
        // DUT-604 — the session's over: cancel every pending step-timer alert so
        // a scheduled banner never fires for a timer whose session the cook has
        // left. Fire-and-forget; captured before `stepTimers` is cleared (the
        // notifier keys on recipe id, not the timer set, so ordering is moot).
        let recipeID = recipe.id
        Task { await stepTimerNotifier.cancelAllStepDone(recipeID: recipeID) }
        // DUT-293/294 — the session's over: drop all step timers + forget which
        // one drove the card, so a re-entry starts clean.
        stepTimers.removeAll()
        liveActivityStepKey = nil
        liveActivityShowingCompleted = false  // DUT-354
        liveActivityUnavailable = false  // DUT-558: a re-entry starts clean
        // AC-7.6 / AC-40.1 — stop any in-flight utterance and release the
        // ducked audio session so the user's music returns to full volume
        // the moment they leave Cook Mode.
        voiceReader.stop()
        isVoiceModeEnabled = false
        // DUT-583 — a re-entry starts clean: idle transport + natural pace.
        playbackState = .idle
        voiceSpeedMultiplier = 1.0
        // Unregister from the Voice Mode command bus so a Siri command fired
        // after Cook Mode closes is a no-op rather than driving a stale session
        // (US-40 / AC-40.5, CL-83). Guard against clobbering a newer session
        // that may already have registered.
        if VoiceCommandBus.shared.handler === self {
            VoiceCommandBus.shared.handler = nil
        }
    }

    /// DUT-529 — belt-and-suspenders idle-timer net for when the app backgrounds
    /// while Cook Mode is still on screen. Restores the *prior* idle-timer value
    /// (undoing `beginCookMode`'s `= true`) WITHOUT tearing down the session:
    /// the Live Activity, step timers, and voice state are all left intact so the
    /// Lock Screen card (US-11) keeps running while backgrounded and the session
    /// resumes cleanly on return. Idempotent — no-op unless a session is live and
    /// the timer is currently held, so it never double-restores against
    /// `endCookMode`.
    public func suspendIdleTimerForBackground() {
        guard didBegin, idleTimer.isDisabled != priorIdleTimerDisabled else { return }
        idleTimer.isDisabled = priorIdleTimerDisabled
    }

    /// DUT-529 — re-arm the idle timer on return to the foreground if the session
    /// is still live (paired with ``suspendIdleTimerForBackground()``). No-op when
    /// no session is running or the timer is already held. Deliberately does NOT
    /// touch `priorIdleTimerDisabled` — that stays captured from the original
    /// `beginCookMode` so the eventual `endCookMode` restores the true prior value.
    public func resumeIdleTimerIfActive() {
        guard didBegin, !idleTimer.isDisabled else { return }
        idleTimer.isDisabled = true
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

    /// DUT-558: whether ActivityKit will accept a `start` right now. Bridges the
    /// controller's `areActivitiesEnabled` (private `liveActivity` is not visible
    /// to the `+Timers` extension) so `reconcileLiveActivity` can tell a permanent
    /// "activities unavailable" apart from a transient start failure.
    var areLiveActivitiesEnabled: Bool {
        liveActivity.areActivitiesEnabled
    }

    /// DUT-558: clear the "activities unavailable" latch so the next timer tick
    /// re-attempts the Live Activity start. Call on scene-activate — the user may
    /// have just toggled Live Activities back on in Settings. A no-op when the
    /// latch was never set.
    public func revalidateLiveActivityAvailability() {
        liveActivityUnavailable = false
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
    ///
    /// DUT-490 / DUT-491: `isCompleted` marks the DUT-354 buzzer linger — a done
    /// (00:00) timer, not a paused one. It renders "Done" (not "Paused") and the
    /// controller stamps a far-future stale date so the single completed push
    /// outlives the linger instead of dimming after ~15s.
    public func updateTimerLiveActivity(
        remainingSeconds: Int,
        stepText: String,
        isPaused: Bool,
        isCompleted: Bool = false
    ) {
        guard liveActivity.isActive else { return }
        let state = CookActivityAttributes.ContentState(
            remainingSeconds: max(remainingSeconds, 0),
            stepText: stepText,
            isPaused: isPaused,
            // DUT-218: running → a live deadline (self-ticking countdown);
            // paused / completed → nil so the views show the frozen snapshot.
            endDate: isPaused
                ? nil : Date(timeIntervalSinceNow: TimeInterval(max(remainingSeconds, 0))),
            isCompleted: isCompleted
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
