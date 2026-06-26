import DODSupport
import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

// US-40 / AC-40.12..AC-40.13 (T-722 nudge; CL-279 / DUT-329) — the Settings →
// Cook Mode Voice section's voice-catalog seam.
//
// `DODFeatureFeed` cannot import `DODFeatureRecipeDetail` (no feature→feature
// edge — CL-122), where the live `AVSpeechSynthesizer` adapter lives. So the
// Settings voice section needs its own narrow seam to read the installed voice
// catalog — to show the resolved quality tier + decide whether the "install a
// better voice" prompt applies. Projected onto the AVFoundation-free
// `DODSupport` value type (`VoiceDescriptor`) so `SettingsViewModel` stays
// testable on the macOS slice with an in-memory double (CL-79 / CL-109).
//
// CL-279 (DUT-329) — there is no in-app voice/gender choice + no preview; Cook
// Mode uses one auto-selected voice and voices are managed only in the iOS
// Settings app. So this seam carries only the catalog read.

/// The installed-voice catalog the Settings voice section reads.
@MainActor
public protocol VoicePreviewing: AnyObject {
    /// The installed voice catalog, projected onto the AVFoundation-free
    /// ``VoiceDescriptor``. Empty when no catalog is available (the preview-less
    /// host double returns `[]`, read as "unknown" — the view-model treats that
    /// conservatively, never surfacing a false prompt).
    func installedVoices() -> [VoiceDescriptor]
}

#if canImport(AVFoundation)

/// Production ``VoicePreviewing`` — reads the live `AVSpeechSynthesisVoice`
/// catalog. The only place in `DODFeatureFeed` that touches AVFoundation.
@MainActor
public final class SystemVoicePreviewer: VoicePreviewing {

    public init() {}

    public func installedVoices() -> [VoiceDescriptor] {
        AVSpeechSynthesisVoice.speechVoices().map(Self.descriptor(for:))
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
