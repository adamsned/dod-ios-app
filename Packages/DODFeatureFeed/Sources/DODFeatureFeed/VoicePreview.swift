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

    /// TEMP (DUT-331) — on-device voice-resolution diagnostic. Reports the voice
    /// the real Cook Mode path would resolve for `languageCode` (name + quality
    /// + identifier), whether `AVSpeechSynthesisVoice(identifier:)` resolves it,
    /// and the per-language catalog. Default returns an empty result so test
    /// doubles need no boilerplate. Remove with the diagnostic UI before merge.
    func voiceDiagnostics(languageCode: String?) -> VoiceDiagnostics

    /// TEMP (DUT-331) — speak a fixed test line through the SAME resolve path the
    /// Cook Mode reader uses, so the user can hear whether the resolved voice is
    /// natural. Default is a no-op. Remove before merge.
    func speakDiagnostic(languageCode: String?)
}

/// TEMP (DUT-331) — diagnostic snapshot of voice resolution on the device.
public struct VoiceDiagnostics: Sendable {
    public let languageCode: String?
    public let resolvedName: String?
    public let resolvedQuality: String?
    public let resolvedIdentifier: String?
    /// Whether `AVSpeechSynthesisVoice(identifier:)` resolves the picked id
    /// (the failure mode the T-887 fix was meant to dodge).
    public let identifierInitSucceeds: Bool
    /// Whether the picked id was found by direct lookup in `speechVoices()`.
    public let foundByDirectLookup: Bool
    /// `"name | quality | language"` per voice matching the language family.
    public let catalogLines: [String]

    public init(
        languageCode: String?,
        resolvedName: String?,
        resolvedQuality: String?,
        resolvedIdentifier: String?,
        identifierInitSucceeds: Bool,
        foundByDirectLookup: Bool,
        catalogLines: [String]
    ) {
        self.languageCode = languageCode
        self.resolvedName = resolvedName
        self.resolvedQuality = resolvedQuality
        self.resolvedIdentifier = resolvedIdentifier
        self.identifierInitSucceeds = identifierInitSucceeds
        self.foundByDirectLookup = foundByDirectLookup
        self.catalogLines = catalogLines
    }
}

/// TEMP (DUT-331) — defaults so non-AVFoundation doubles need no boilerplate.
extension VoicePreviewing {
    public func voiceDiagnostics(languageCode: String?) -> VoiceDiagnostics {
        VoiceDiagnostics(
            languageCode: languageCode,
            resolvedName: nil,
            resolvedQuality: nil,
            resolvedIdentifier: nil,
            identifierInitSucceeds: false,
            foundByDirectLookup: false,
            catalogLines: []
        )
    }

    public func speakDiagnostic(languageCode: String?) {}
}

#if canImport(AVFoundation)

/// Production ``VoicePreviewing`` — reads the live `AVSpeechSynthesisVoice`
/// catalog. The only place in `DODFeatureFeed` that touches AVFoundation.
@MainActor
public final class SystemVoicePreviewer: VoicePreviewing {

    public init() {}

    /// TEMP (DUT-331) — held for the diagnostic "Speak test" button.
    private let diagnosticSynthesizer = AVSpeechSynthesizer()

    public func installedVoices() -> [VoiceDescriptor] {
        AVSpeechSynthesisVoice.speechVoices().map(Self.descriptor(for:))
    }

    /// TEMP (DUT-331) — see protocol doc.
    public func voiceDiagnostics(languageCode: String?) -> VoiceDiagnostics {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let descriptors = voices.map(Self.descriptor(for:))
        let pickedID = VoiceSelector.bestVoiceIdentifier(from: descriptors, languageCode: languageCode)
        let picked = pickedID.flatMap { id in voices.first(where: { $0.identifier == id }) }
        let initVoice = pickedID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
        let family = languageCode.map { String($0.prefix(2)).lowercased() }
        let lines =
            voices
            .filter { voice in
                guard let family else { return true }
                return voice.language.lowercased().hasPrefix(family)
            }
            .sorted { $0.language == $1.language ? $0.name < $1.name : $0.language < $1.language }
            .map { "\($0.name) | \(Self.qualityLabel($0.quality)) | \($0.language)" }
        return VoiceDiagnostics(
            languageCode: languageCode,
            resolvedName: picked?.name,
            resolvedQuality: picked.map { Self.qualityLabel($0.quality) },
            resolvedIdentifier: pickedID,
            identifierInitSucceeds: initVoice != nil,
            foundByDirectLookup: picked != nil,
            catalogLines: lines
        )
    }

    /// TEMP (DUT-331) — speak a fixed line via the same resolve path Cook Mode uses.
    public func speakDiagnostic(languageCode: String?) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let descriptors = voices.map(Self.descriptor(for:))
        let utterance = AVSpeechUtterance(
            string: "This is the Cook Mode voice. Layer the noodles, then spread the meat mixture evenly over the top."
        )
        let picked = VoiceSelector.bestVoiceIdentifier(from: descriptors, languageCode: languageCode)
            .flatMap { id in voices.first(where: { $0.identifier == id }) }
        if let picked { utterance.voice = picked }
        diagnosticSynthesizer.stopSpeaking(at: .immediate)
        diagnosticSynthesizer.speak(utterance)
    }

    /// TEMP (DUT-331) — quality tier label for the diagnostic.
    static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Default"
        }
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
