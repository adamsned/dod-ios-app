import DODSupport
import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

// US-40 / AC-40.10..AC-40.13 (T-721 picker extension + T-722 nudge) — the
// Settings → Cook Mode Voice section's voice seam.
//
// `DODFeatureFeed` cannot import `DODFeatureRecipeDetail` (no feature→feature
// edge — CL-122), where the `SpeechSynthesizing` protocol + the live
// `AVSpeechSynthesizer` adapter live. So the Settings voice section needs its
// own narrow seam to (a) read the installed voice catalog (to show the
// resolved quality tier + decide whether the "download a better voice" nudge
// applies) and (b) speak a one-line preview with the user's current gender
// pick. Both are projected onto the AVFoundation-free `DODSupport` value types
// (`VoiceDescriptor`, `VoicePreference`) so `SettingsViewModel` stays testable
// on the macOS `swift test` slice with an in-memory double — exactly the
// `SpeechSynthesizing` seam pattern `VoiceReader` already uses (CL-79 / CL-109).

/// The voice catalog + preview surface the Settings voice section drives.
///
/// Production wiring (composition root, behind `#if canImport(AVFoundation)`)
/// passes a ``SystemVoicePreviewer`` that reads the live
/// `AVSpeechSynthesisVoice.speechVoices()` catalog and speaks through an
/// `AVSpeechSynthesizer`; the L1 suite injects a recording double so the
/// quality readout, nudge-visibility logic, and preview trigger are asserted
/// with zero real-audio dependency.
@MainActor
public protocol VoicePreviewing: AnyObject {

    /// The installed voice catalog, projected onto the AVFoundation-free
    /// ``VoiceDescriptor`` so the view-model can rank quality + gender without
    /// importing AVFoundation. Empty when no catalog is available (e.g. the
    /// preview-less host double returns `[]`, which reads as "unknown" — the
    /// view-model treats that conservatively, never surfacing a false nudge).
    func installedVoices() -> [VoiceDescriptor]

    /// Speak a short, fixed sample line using the best installed voice for the
    /// supplied language + preference (resolved via ``VoiceSelector`` exactly
    /// as Cook Mode does), so the user hears the *actual* voice a cook session
    /// would use. Interrupts any in-flight preview first so repeated taps never
    /// stack two voices.
    func speakPreview(_ text: String, languageCode: String?, preference: VoicePreference)

    /// Stop any in-flight preview (called when the user leaves Settings so a
    /// preview never trails the screen).
    func stopPreview()
}

#if canImport(AVFoundation)

/// Production ``VoicePreviewing`` — backed by `AVSpeechSynthesizer`.
///
/// The only place in `DODFeatureFeed` that touches AVFoundation. Mirrors the
/// `DODFeatureRecipeDetail.SystemSpeechSynthesizer` voice-resolution path
/// (best installed tier honoring gender, via ``VoiceSelector``) so the
/// Settings preview sounds byte-for-byte like the Cook Mode read-aloud the
/// user will actually hear — the whole point of the "Preview voice" button.
@MainActor
public final class SystemVoicePreviewer: VoicePreviewing {

    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func installedVoices() -> [VoiceDescriptor] {
        AVSpeechSynthesisVoice.speechVoices().map(Self.descriptor(for:))
    }

    public func speakPreview(
        _ text: String,
        languageCode: String?,
        preference: VoicePreference
    ) {
        // Interrupt any in-flight preview first (parallels VoiceReader's
        // AC-40.7 stop-before-speak so two previews never overlap).
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        let descriptors = installedVoices()
        if let identifier = VoiceSelector.bestVoiceIdentifier(
            from: descriptors,
            languageCode: languageCode,
            preference: preference
        ), let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else if let languageCode {
            // Selector found no language match — same fallback as the Cook
            // Mode reader: the compact voice for the language, else nil
            // (platform default).
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }
        synthesizer.speak(utterance)
    }

    public func stopPreview() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Project an `AVSpeechSynthesisVoice` onto the AVFoundation-free
    /// ``VoiceDescriptor``. Mirrors `SystemSpeechSynthesizer.descriptor(for:)`
    /// in `DODFeatureRecipeDetail` (the two packages can't share it without a
    /// dependency edge, so the projection is intentionally duplicated — it's a
    /// four-field copy, not logic worth coupling two features over).
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
}

#endif
