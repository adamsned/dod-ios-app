import DODSupport
import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

// US-40 / AC-40.12 (T-722 nudge; CL-279 / DUT-329; DUT-332) — the Settings →
// Cook Mode Voice section's voice seam.
//
// `DODFeatureFeed` cannot import `DODFeatureRecipeDetail` (no feature→feature
// edge — CL-122), where the live `AVSpeechSynthesizer` adapter lives. So the
// Settings voice section needs its own narrow seam to read the installed voice
// catalog (for the "install a better voice" gate), to name the resolved voice
// (the "Voice: <name> (<quality>)" readout), and to preview it (the speaker
// button). Catalog reads are projected onto the AVFoundation-free `DODSupport`
// value type (`VoiceDescriptor`) so `SettingsViewModel` stays testable on the
// macOS slice with an in-memory double (CL-79 / CL-109).
//
// DUT-332 — Cook Mode uses ONE auto-selected voice (CL-279 — no in-app picker /
// gender choice); the section just names the resolved voice + previews it. The
// resolve path mirrors `SystemSpeechSynthesizer.resolveVoice`, including the
// DUT-331 exclusion of unusable Siri voices.

/// The installed-voice catalog + named-voice preview the Settings section reads.
@MainActor
public protocol VoicePreviewing: AnyObject {
    /// The installed voice catalog, projected onto the AVFoundation-free
    /// ``VoiceDescriptor``. Empty when no catalog is available (the preview-less
    /// host double returns `[]`, read as "unknown" — the view-model treats that
    /// conservatively, never surfacing a false prompt).
    func installedVoices() -> [VoiceDescriptor]

    /// DUT-332 — the display name of the voice Cook Mode resolves for
    /// `languageCode` (e.g. "Jamie"), or `nil` if none resolves. Drives the
    /// Settings "Voice: <name> (<quality>)" readout. Default `nil` so the
    /// non-AVFoundation host double needs no boilerplate.
    func resolvedVoiceName(languageCode: String?) -> String?

    /// DUT-332 — speak a short sample line in the resolved voice (the cell's
    /// speaker button). Default no-op for the host double.
    func previewVoice(languageCode: String?)
}

/// Defaults so non-AVFoundation doubles need no boilerplate.
extension VoicePreviewing {
    public func resolvedVoiceName(languageCode: String?) -> String? { nil }
    public func previewVoice(languageCode: String?) {}
}

#if canImport(AVFoundation)

/// Production ``VoicePreviewing`` — reads the live `AVSpeechSynthesisVoice`
/// catalog. The only place in `DODFeatureFeed` that touches AVFoundation.
@MainActor
public final class SystemVoicePreviewer: VoicePreviewing {

    public init() {}

    /// Held across previews so a rapid second tap interrupts the first.
    private let previewSynthesizer = AVSpeechSynthesizer()

    /// DUT-115 — the sample line the Settings preview speaks (a real recipe step).
    static let previewSampleLine =
        "Layer the noodles, then spread the meat mixture evenly over the top."

    public func installedVoices() -> [VoiceDescriptor] {
        AVSpeechSynthesisVoice.speechVoices().map(Self.descriptor(for:))
    }

    public func resolvedVoiceName(languageCode: String?) -> String? {
        resolvedVoice(languageCode: languageCode)?.name
    }

    public func previewVoice(languageCode: String?) {
        let utterance = AVSpeechUtterance(string: Self.previewSampleLine)
        utterance.voice = resolvedVoice(languageCode: languageCode)
        previewSynthesizer.stopSpeaking(at: .immediate)
        previewSynthesizer.speak(utterance)
    }

    /// The voice Cook Mode would resolve for `languageCode`, via the shared
    /// ``VoiceSelector`` (Siri voices excluded — DUT-331). Mirrors
    /// `SystemSpeechSynthesizer.resolveVoice` so the readout + preview match
    /// what Cook Mode actually speaks with.
    private func resolvedVoice(languageCode: String?) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let descriptors = voices.map(Self.descriptor(for:))
        guard
            let id = VoiceSelector.bestVoiceIdentifier(from: descriptors, languageCode: languageCode)
        else {
            return nil
        }
        return voices.first(where: { $0.identifier == id })
    }

    /// Project an `AVSpeechSynthesisVoice` onto the AVFoundation-free
    /// ``VoiceDescriptor``. Mirrors `SystemSpeechSynthesizer.descriptor(for:)`
    /// in `DODFeatureRecipeDetail` (the two packages can't share it without a
    /// dependency edge, so the four-field projection is intentionally duplicated).
    static func descriptor(for voice: AVSpeechSynthesisVoice) -> VoiceDescriptor {
        let quality: VoiceQuality
        switch voice.quality {
        case .premium: quality = .premium
        case .enhanced: quality = .enhanced
        default: quality = .default
        }
        return VoiceDescriptor(
            identifier: voice.identifier,
            languageCode: voice.language,
            quality: quality
        )
    }
}

#endif
