import DODSupport
import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// The narrow slice of `AVSpeechSynthesizer` that ``VoiceReader`` drives.
///
/// Spec trace: US-40 (Cook Mode Voice Mode), AC-40.7 (speaking a new step
/// interrupts the prior utterance), CL-79 (the testability-seam decision).
///
/// `VoiceReader` depends on this protocol rather than concretely on
/// `AVSpeechSynthesizer` so the reader's speak/stop/pause/resume state
/// machine can be exercised with a mock under `swift test` — no real audio
/// hardware, no audio session. The production conformance lives in
/// ``SystemSpeechSynthesizer`` and is the only place that touches the real
/// `AVSpeechSynthesizer` API. This mirrors the ``CookLiveActivityController``
/// protocol seam (US-11) that lets ``CookModeViewModel`` build + test on the
/// package's macOS slice without ActivityKit.
@MainActor
public protocol SpeechSynthesizing: AnyObject {

    /// True while an utterance is actively being spoken.
    var isSpeaking: Bool { get }

    /// True while an utterance has been paused (and can be resumed).
    var isPaused: Bool { get }

    /// The speech rate applied to the next utterance (DUT-325). Expressed as
    /// the raw `AVSpeechUtterance.rate` value; production clamps it around
    /// `AVSpeechUtteranceDefaultSpeechRate`. A default implementation makes
    /// this a no-op store so mocks/fallbacks that don't model pacing keep
    /// compiling — only ``SystemSpeechSynthesizer`` actually applies it.
    var speechRate: Float { get set }

    /// DUT-390 — invoked (on the main actor) when the synthesizer's queue
    /// drains: the last utterance finished or was cancelled and nothing else is
    /// speaking. ``VoiceReader`` uses it to release the audio session after a
    /// one-shot read (e.g. replay while Voice Mode is off) so ducked audio isn't
    /// left dipped for the rest of the cook. Declared as a requirement — not
    /// just an extension member — so the assignment reaches
    /// ``SystemSpeechSynthesizer``'s real storage through dynamic dispatch (an
    /// extension-only property would statically dispatch to the no-op default).
    /// A default no-op store lets mocks/fallbacks satisfy it without wiring a
    /// real `AVSpeechSynthesizerDelegate`.
    var onQueueDidEmpty: (() -> Void)? { get set }

    /// Enqueue and begin speaking the supplied text. ``VoiceReader`` always
    /// calls ``stop()`` first (AC-40.7), so a conformer may assume it is
    /// starting from a stopped state.
    func speak(_ text: String)

    /// Speak the supplied text using the system-default voice for the given
    /// language code (AC-40.2 / CL-79). Declared as a requirement — not just
    /// an extension method — so the production ``SystemSpeechSynthesizer``
    /// override is reached through dynamic dispatch when ``VoiceReader`` holds
    /// the engine as a `SpeechSynthesizing`. A default implementation forwards
    /// to ``speak(_:)`` so mocks only have to record the text and never touch
    /// any AVFoundation type.
    func speak(localizedText text: String, languageCode: String?)

    /// Immediately stop any in-flight or paused utterance.
    func stop()

    /// Pause the current utterance at the next word boundary.
    func pause()

    /// Resume a paused utterance.
    func continueSpeaking()

    /// DUT-328 — the installed voice catalog, projected onto the
    /// AVFoundation-free ``VoiceDescriptor``. Drives the Cook Mode "this may
    /// sound robotic, get a better voice" prompt (which asks ``VoiceSelector``
    /// whether any natural voice is installed). A default returns `[]` so mocks +
    /// the non-AVFoundation fallback need no boilerplate; ``SystemSpeechSynthesizer``
    /// overrides with the real `AVSpeechSynthesisVoice.speechVoices()` catalog.
    func installedVoiceDescriptors() -> [VoiceDescriptor]
}

/// Reads Cook Mode steps aloud using on-device speech synthesis.
///
/// Spec trace: US-40 / AC-40.2 (read the current step via the system-default
/// voice for `Locale.current`), AC-40.4 (pause / resume), AC-40.6 (audio
/// ducking — `.playback` + `.duckOthers`), AC-40.7 (a new step interrupts the
/// prior utterance). The synthesizer + voice/locale + audio-session decisions
/// are captured in CL-79.
///
/// This is the standalone T-690a deliverable — it wraps the speech engine and
/// manages the audio session, but knows nothing about Cook Mode itself. The
/// Voice Mode toggle, the re-read-on-step-change driver, and the four Siri
/// `AppIntent`s that drive it are T-690b and live elsewhere.
///
/// The synthesizer is injectable (``SpeechSynthesizing``) so the reader is
/// unit-testable with a mock; production constructs it with the real
/// ``SystemSpeechSynthesizer``.
@MainActor
public final class VoiceReader {

    private let synthesizer: SpeechSynthesizing

    /// Tracks whether we have activated the shared audio session, so we only
    /// activate once (lazily on the first ``speak(_:)``) and only deactivate
    /// when we actually have an active session to release. Merely holding a
    /// `VoiceReader` never disturbs other audio (CL-79).
    ///
    /// `nonisolated(unsafe)` so ``deinit`` (nonisolated in Swift 6) can read it
    /// to release a still-active session (DUT-390). Only ever mutated on the
    /// main actor, and `deinit` runs once no other reference survives, so the
    /// unchecked access is safe.
    nonisolated(unsafe) private var didActivateAudioSession = false

    /// DUT-390 — when true, the audio session is held open across utterances
    /// (Voice Mode is on) and the queue-drained callback must NOT release it,
    /// so ducked audio doesn't flap between steps. False for one-shot reads
    /// (e.g. replay while Voice Mode is off), where completion releases the
    /// session so other audio un-ducks promptly.
    private var holdsSessionOpen = false

    /// DUT-283 — true while we hold an activated audio session. Exposed for
    /// tests; the real `AVAudioSession` work is iOS-only.
    var hasActiveAudioSession: Bool { didActivateAudioSession }

    #if os(iOS)
    nonisolated(unsafe) private var interruptionObserver: (any NSObjectProtocol)?
    nonisolated(unsafe) private var mediaResetObserver: (any NSObjectProtocol)?

    /// DUT-385 — set on interruption `.began` when we were mid-utterance, so
    /// the `.ended` handler knows to resume even though iOS may have cleared
    /// the synthesizer's `isPaused` flag (interrupting a `.playback` session
    /// cancels the in-flight utterance rather than parking it resumably).
    private var wasInterruptedWhileSpeaking = false
    #endif

    /// The language code used to resolve the speech voice — the device's
    /// current locale per AC-40.2 / CL-79. Captured at init so the same voice
    /// is used for every utterance in a cook session.
    private let languageCode: String?

    /// - Parameters:
    ///   - synthesizer: the speech engine. Defaults to the production
    ///     ``SystemSpeechSynthesizer`` (a thin `AVSpeechSynthesizer` adapter);
    ///     tests inject a mock.
    ///   - locale: the locale whose language drives voice selection. Defaults
    ///     to `Locale.current` per CL-79 (the system-default voice for the
    ///     device's locale, with the platform default as the fallback).
    public init(
        synthesizer: SpeechSynthesizing = SystemSpeechSynthesizer(),
        locale: Locale = .current
    ) {
        self.synthesizer = synthesizer
        self.languageCode = locale.language.languageCode?.identifier
        // Seed the platform default so the first utterance reads at a natural
        // pace (a fresh `Float` would otherwise be 0). DUT-325.
        self.synthesizer.speechRate = Self.defaultRate
        // DUT-390 — release the audio session when the queue drains unless
        // Voice Mode is holding it open, so a one-shot read (replay) doesn't
        // leave other audio ducked for the rest of the cook.
        self.synthesizer.onQueueDidEmpty = { [weak self] in
            guard let self, !self.holdsSessionOpen else { return }
            self.deactivateAudioSession()
        }
        #if os(iOS)
        registerAudioSessionObservers()
        #endif
    }

    /// DUT-390 — Voice Mode holds the audio session open across steps; a
    /// one-shot read does not. ``CookModeViewModel`` sets this true when Voice
    /// Mode turns on and false when it turns off, so the queue-drained callback
    /// only releases the session for one-shot reads.
    public func setSessionHold(_ hold: Bool) {
        holdsSessionOpen = hold
    }

    /// DUT-283 — force the next `speak(_:)` to re-activate the audio session.
    /// Called by the interruption / media-reset observers once the system has
    /// torn our session down, so Voice Mode recovers instead of going silent for
    /// the rest of the cook.
    func invalidateAudioSession() {
        didActivateAudioSession = false
    }

    /// True while a step is being read aloud.
    public var isSpeaking: Bool { synthesizer.isSpeaking }

    /// True while reading has been paused (and can be resumed).
    public var isPaused: Bool { synthesizer.isPaused }

    /// DUT-325 — the speech rate for the **next** utterance, forwarded straight
    /// to the underlying engine. Session-only; never persisted. `VoiceReader`
    /// owns the clamped step helpers (``speedUp()`` / ``slowDown()``) so the
    /// Cook Mode menu can nudge pacing without knowing the AVFoundation bounds.
    public var speechRate: Float {
        get { synthesizer.speechRate }
        set { synthesizer.speechRate = newValue }
    }

    /// The lowest rate the session menu allows — half the platform default
    /// (≈0.5×). Slow enough to follow a tricky step, never so slow it drags.
    static var minimumRate: Float { Self.defaultRate * 0.5 }
    /// The highest rate the session menu allows — double the platform default
    /// (≈2×). Fast enough to skim, never so fast it garbles.
    static var maximumRate: Float { Self.defaultRate * 2 }
    /// Per-tap increment (a fifth of the default span) so a couple of taps
    /// spans the comfortable range.
    static var rateStep: Float { Self.defaultRate * 0.15 }

    /// The platform default speech rate. `AVSpeechUtteranceDefaultSpeechRate`
    /// where AVFoundation exists; a matching constant on the fallback slice.
    static var defaultRate: Float {
        #if canImport(AVFoundation)
        AVSpeechUtteranceDefaultSpeechRate
        #else
        0.5
        #endif
    }

    /// DUT-325 — nudge the session speech rate up one step (clamped). Returns
    /// the new rate so the caller can decide whether to re-speak.
    @discardableResult
    public func speedUp() -> Float {
        speechRate = min(Self.maximumRate, speechRate + Self.rateStep)
        return speechRate
    }

    /// DUT-325 — nudge the session speech rate down one step (clamped).
    @discardableResult
    public func slowDown() -> Float {
        speechRate = max(Self.minimumRate, speechRate - Self.rateStep)
        return speechRate
    }

    /// Speak the supplied text aloud.
    ///
    /// Activates the `.playback` + `.duckOthers` audio session on the first
    /// call (AC-40.6) and stops any in-flight or paused utterance before
    /// starting the new one (AC-40.7) so rapid step changes never stack two
    /// voices.
    public func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activateAudioSessionIfNeeded()
        // AC-40.7: interrupt whatever is currently (or pausedly) speaking so
        // the listener only ever hears the step they landed on.
        synthesizer.stop()
        synthesizer.speak(localizedText: trimmed, languageCode: languageCode)
    }

    /// Stop reading and release the audio session so ducked audio returns to
    /// full volume (AC-40.6).
    public func stop() {
        synthesizer.stop()
        deactivateAudioSession()
    }

    /// Pause the current utterance at the next word boundary (AC-40.4).
    public func pause() {
        synthesizer.pause()
    }

    /// Resume a paused utterance (AC-40.4).
    public func resume() {
        synthesizer.continueSpeaking()
    }

    /// DUT-328 — the installed voice catalog (AVFoundation-free projection),
    /// for the Cook Mode "get a better voice" prompt's natural-voice check.
    public func installedVoices() -> [VoiceDescriptor] {
        synthesizer.installedVoiceDescriptors()
    }

    // MARK: - Audio session (iOS only)

    private func activateAudioSessionIfNeeded() {
        guard !didActivateAudioSession else { return }
        didActivateAudioSession = true
        #if os(iOS)
        // `.playback` so the step is audible even with the silent switch on
        // (the user opted into Voice Mode), `.duckOthers` so background
        // music/podcasts dip rather than stop while a step is read (CL-79).
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // A failed audio-session activation must never break Voice Mode;
            // synthesis still works, other audio just won't duck. Swallow,
            // matching the SystemCookLiveActivityController failure posture.
            didActivateAudioSession = false
        }
        #endif
    }

    private func deactivateAudioSession() {
        guard didActivateAudioSession else { return }
        didActivateAudioSession = false
        #if os(iOS)
        // `.notifyOthersOnDeactivation` so the ducked audio returns to full
        // volume immediately (CL-79).
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    #if os(iOS)
    // MARK: - Audio interruption recovery (DUT-283)

    /// Observe the events that tear our `.playback`/`.duckOthers` session down
    /// out from under us — a phone call / Siri (`interruption`) and a media-
    /// server reset — so the next `speak(_:)` re-activates instead of staying
    /// silent for the rest of the cook. Registered once at init; removed in deinit.
    private func registerAudioSessionObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Pull the Sendable values out of the non-Sendable Notification here,
            // then hop to the main actor with only Sendable data (Swift 6).
            let info = note.userInfo
            let typeRaw = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleAudioInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }
        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // A media-server reset clears ALL audio state — force a fresh category
            // + activation on the next read.
            MainActor.assumeIsolated { self?.invalidateAudioSession() }
        }
    }

    private func handleAudioInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }
        switch type {
        case .began:
            // DUT-385: interrupting a `.playback` session CANCELS the in-flight
            // utterance (afterward `isPaused` is false), so the `.ended` resume
            // path — gated on `isPaused` — was dead for the common phone-call /
            // Siri case. Park it ourselves: pause now (best effort at parking it
            // resumably) and remember we were speaking so `.ended` can resume off
            // our own flag rather than the engine's cleared paused state.
            if synthesizer.isSpeaking {
                synthesizer.pause()
                wasInterruptedWhileSpeaking = true
            }
            // The system deactivated our session — the next speak() must reactivate.
            invalidateAudioSession()
        case .ended:
            invalidateAudioSession()
            // If the system says we may resume and we were mid-utterance when the
            // interruption began, duck + continue right away rather than waiting
            // for the next step. DUT-385: gate on our own flag (or a still-paused
            // engine), not solely `isPaused`, which iOS may have cleared.
            let options = optionsRaw.map(AVAudioSession.InterruptionOptions.init(rawValue:))
            let shouldResume = options?.contains(.shouldResume) == true
            if shouldResume, wasInterruptedWhileSpeaking || synthesizer.isPaused {
                activateAudioSessionIfNeeded()
                synthesizer.continueSpeaking()
            }
            wasInterruptedWhileSpeaking = false
        @unknown default:
            break
        }
    }
    #endif

    deinit {
        #if os(iOS)
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let mediaResetObserver {
            NotificationCenter.default.removeObserver(mediaResetObserver)
        }
        // DUT-390 — if the reader is dropped while it still holds an activated
        // session (e.g. Cook Mode torn down off the `endCookMode` path after a
        // replay activated it), release it so ducked audio isn't left dipped.
        if didActivateAudioSession {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        }
        #endif
    }
}
