import DODSupport
import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

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

    /// DUT-325 — default no-op pacing store. Conformers that don't model speech
    /// rate (test mocks, the non-AVFoundation fallback shape) inherit this so
    /// the protocol requirement is satisfied without per-conformer boilerplate;
    /// ``SystemSpeechSynthesizer`` overrides with a real stored property that
    /// drives `AVSpeechUtterance.rate`.
    var speechRate: Float {
        get { 0 }
        // Intentional no-op: conformers that care (SystemSpeechSynthesizer)
        // override with a real stored property; the rest discard pacing.
        // swiftlint:disable:next unused_setter_value
        set {}
    }
}

#if canImport(AVFoundation)

/// Production ``SpeechSynthesizing`` — backed by `AVSpeechSynthesizer`.
///
/// `AVSpeechSynthesizer` is available on both iOS and macOS, so this type
/// compiles on the package's macOS `swift test` slice; the iOS-only audio
/// session lives in ``VoiceReader`` behind `#if os(iOS)`.
///
/// US-40 / AC-40.9..AC-40.11 (T-720, 2026-05-29) — the resolved voice is the
/// **best installed quality tier** for the supplied language + the user's
/// gender preference, via ``VoiceSelector``, NOT the compact-tier voice that
/// `AVSpeechSynthesisVoice(language:)` returns. The prior behavior picked the
/// default (concatenative, "robotic") voice for a language even when an
/// `enhanced` Siri voice was already installed; this path enumerates the live
/// catalog and explicitly reaches the natural tier. Falls back to the prior
/// `AVSpeechSynthesisVoice(language:)` behavior (then the platform default)
/// when the selector finds no language match, so a locale with no installed
/// voices degrades exactly as before. CL-109 captures the rationale.
@MainActor
public final class SystemSpeechSynthesizer: SpeechSynthesizing {

    private let synthesizer = AVSpeechSynthesizer()
    private let preferenceStore: VoicePreferenceStore

    /// DUT-325 — the rate applied to the next utterance. Defaults to the
    /// platform default; ``VoiceReader`` nudges it (clamped) for the session.
    /// Clamped on write to the AV-valid `[Min...Max]` range so an out-of-band
    /// value can never reach the engine.
    public var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate {
        didSet {
            speechRate = min(
                AVSpeechUtteranceMaximumSpeechRate,
                max(AVSpeechUtteranceMinimumSpeechRate, speechRate)
            )
        }
    }

    public init(preferenceStore: VoicePreferenceStore = VoicePreferenceStore()) {
        self.preferenceStore = preferenceStore
    }

    public var isSpeaking: Bool { synthesizer.isSpeaking }

    public var isPaused: Bool { synthesizer.isPaused }

    public func speak(_ text: String) {
        speak(localizedText: text, languageCode: nil)
    }

    public func speak(localizedText text: String, languageCode: String?) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolveVoice(languageCode: languageCode)
        // DUT-325 — honor the session-selected pace (default unless the user
        // nudged Slower/Faster from the Cook Mode voice menu).
        utterance.rate = speechRate
        synthesizer.speak(utterance)
    }

    /// Resolve the best installed voice for the language + the user's gender
    /// preference. Returns `nil` only when neither the quality-aware selector
    /// NOR the legacy `(language:)` initializer produces a voice, in which
    /// case the synthesizer uses the platform default (the original CL-79
    /// fallback).
    private func resolveVoice(languageCode: String?) -> AVSpeechSynthesisVoice? {
        let catalog = AVSpeechSynthesisVoice.speechVoices()
        let descriptors = catalog.map(Self.descriptor(for:))
        let preference = preferenceStore.preference()

        if let identifier = VoiceSelector.bestVoiceIdentifier(
            from: descriptors,
            languageCode: languageCode,
            preference: preference
        ), let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }

        // Selector found no language match — preserve the prior behavior:
        // the compact voice for the language, then the platform default.
        if let languageCode {
            return AVSpeechSynthesisVoice(language: languageCode)
        }
        return nil
    }

    /// Project an `AVSpeechSynthesisVoice` onto the AVFoundation-free
    /// ``VoiceDescriptor`` the selector consumes.
    static func descriptor(for voice: AVSpeechSynthesisVoice) -> VoiceDescriptor {
        let gender: VoiceGender
        switch voice.gender {
        case .male: gender = .male
        case .female: gender = .female
        default: gender = .unspecified
        }

        let quality: VoiceQuality
        switch voice.quality {
        case .premium: quality = .premium
        case .enhanced: quality = .enhanced
        default: quality = .default
        }

        return VoiceDescriptor(
            identifier: voice.identifier,
            languageCode: voice.language,
            gender: gender,
            quality: quality,
            name: voice.name
        )
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
    /// DUT-325 — pacing store on the fallback slice (no real engine to drive).
    public var speechRate: Float = 0.5

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
