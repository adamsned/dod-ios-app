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
    private var didActivateAudioSession = false

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
    }

    /// True while a step is being read aloud.
    public var isSpeaking: Bool { synthesizer.isSpeaking }

    /// True while reading has been paused (and can be resumed).
    public var isPaused: Bool { synthesizer.isPaused }

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
}

extension SpeechSynthesizing {
    /// Convenience that lets ``VoiceReader`` hand the engine a locale-resolved
    /// utterance without the protocol surface having to know about
    /// `AVSpeechUtterance`. The default implementation forwards the plain
    /// text; ``SystemSpeechSynthesizer`` overrides to attach the resolved
    /// `AVSpeechSynthesisVoice`. Mocks inherit this default (they only record
    /// the text), keeping the protocol free of any AVFoundation type.
    func speak(localizedText text: String, languageCode: String?) {
        speak(text)
    }
}

#if canImport(AVFoundation)

/// Production ``SpeechSynthesizing`` — backed by `AVSpeechSynthesizer`.
///
/// `AVSpeechSynthesizer` is available on both iOS and macOS, so this type
/// compiles on the package's macOS `swift test` slice; the iOS-only audio
/// session lives in ``VoiceReader`` behind `#if os(iOS)`. The resolved voice
/// is the system default for the supplied language code per AC-40.2 / CL-79,
/// falling back to the platform default when no localized voice is available.
@MainActor
public final class SystemSpeechSynthesizer: SpeechSynthesizing {

    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public var isSpeaking: Bool { synthesizer.isSpeaking }

    public var isPaused: Bool { synthesizer.isPaused }

    public func speak(_ text: String) {
        speak(localizedText: text, languageCode: nil)
    }

    public func speak(localizedText text: String, languageCode: String?) {
        let utterance = AVSpeechUtterance(string: text)
        // Leave `.voice` nil when no localized voice resolves — the
        // synthesizer then uses the system default, which is the intended
        // fallback (CL-79). Default rate is used (no custom pacing in v1).
        if let languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    public func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
}

#else

/// Fallback ``SpeechSynthesizing`` for the (hypothetical) platform without
/// AVFoundation. Keeps ``VoiceReader``'s default initializer compiling
/// everywhere; the production targets (iOS / macOS) both have AVFoundation, so
/// this path is never taken in practice.
@MainActor
public final class SystemSpeechSynthesizer: SpeechSynthesizing {

    public private(set) var isSpeaking = false
    public private(set) var isPaused = false

    public init() {}

    public func speak(_ text: String) {
        isSpeaking = true
        isPaused = false
    }

    public func stop() {
        isSpeaking = false
        isPaused = false
    }

    public func pause() {
        if isSpeaking {
            isPaused = true
        }
    }

    public func continueSpeaking() {
        if isPaused {
            isPaused = false
        }
    }
}

#endif
