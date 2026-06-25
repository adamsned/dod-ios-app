import DODSupport
import Foundation

/// US-40 / AC-40.12 + AC-40.13 — the Settings Cook Mode Voice section's
/// quality readout, "download a better voice" nudge, and Preview-voice action.
///
/// Extracted from `SettingsViewModel.swift` so that file stays under the
/// SwiftLint 400-line file_length cap (the same split `RecipeStore +
/// RecipeStore+Containers.swift` and `SettingsViewModel+CloudSync.swift`
/// follow). The stored dependencies (`voicePreviewer`, `voiceLanguageCode`,
/// `voicePreferenceStore`, `defaults`) live on the primary declaration; the
/// derived voice state + actions live here.
///
/// Why these belong in the view-model, not the view: the quality readout + the
/// nudge-visibility decision are pure functions of the installed catalog + the
/// dismissal flag, so they're unit-tested on the macOS slice with a recording
/// `VoicePreviewing` double — no AVFoundation, no simulator (CL-109).
///
/// Spec trace: US-40 AC-40.12 (show resolved quality tier + Preview),
/// AC-40.13 (download nudge when only the compact tier is installed); CL-123
/// (a once-dismissed nudge never re-shows).
extension SettingsViewModel {

    /// The fixed sample line the Preview-voice button speaks. A real recipe
    /// step (not "the quick brown fox") so the user judges the voice on the
    /// kind of text Cook Mode actually reads. Public so the L1 suite can pin
    /// the exact string the preview seam receives.
    public static let voicePreviewSampleLine =
        "Layer the noodles, then spread a third of the meat mixture evenly over the top."

    /// The synthesis-quality tier of the voice Cook Mode would resolve right
    /// now for this device's language + the user's gender pick — the load-
    /// bearing "are you on a robotic voice?" readout (AC-40.12). `nil` when no
    /// catalog is available (no previewer wired, or an empty catalog) so the
    /// view can render an honest "Unknown" rather than a guessed tier.
    ///
    /// Reads the *resolved* voice's tier (gender-aware), not merely the best
    /// installed tier, so the readout tracks the picker: if the user flips to a
    /// gender that only has a compact voice installed, the readout drops to
    /// Default even when the other gender has an enhanced voice — exactly what
    /// they'll hear, and the cue to download the matching natural voice.
    public var resolvedVoiceQuality: VoiceQuality? {
        guard let voicePreviewer else { return nil }
        let catalog = voicePreviewer.installedVoices()
        guard !catalog.isEmpty else { return nil }
        let preference = VoicePreference(gender: voiceGender, voiceIdentifier: voiceIdentifier)
        guard
            let identifier = VoiceSelector.bestVoiceIdentifier(
                from: catalog,
                languageCode: voiceLanguageCode,
                preference: preference
            ),
            let descriptor = catalog.first(where: { $0.identifier == identifier })
        else {
            return nil
        }
        return descriptor.quality
    }

    /// DUT-327 — the installed voices for this device's language, for the
    /// Settings → Cook Mode Voice picker (Automatic + each named voice). Sorted
    /// natural-first then by name (via ``VoiceSelector/voicesForLanguage(_:in:)``)
    /// so the good voices are at the top. Empty when no previewer is wired, in
    /// which case the picker shows only "Automatic". Doubles as a diagnostic: if
    /// the voice the user downloaded appears here, the app can see + use it.
    public var installedVoiceChoices: [VoiceDescriptor] {
        guard let voicePreviewer else { return [] }
        return VoiceSelector.voicesForLanguage(voiceLanguageCode, in: voicePreviewer.installedVoices())
    }

    /// Whether the "download a better voice" tip should surface in the Settings
    /// voice section (AC-40.13). True only when **all three** hold:
    ///   1. a catalog is available (a previewer is wired + reports voices),
    ///   2. no natural (`.enhanced` / `.premium`) voice is installed for this
    ///      device's language — i.e. the best installed tier is the compact
    ///      "robotic" one, the exact stock-device state the nudge targets, and
    ///   3. the user hasn't already dismissed the tip (CL-123).
    ///
    /// Deliberately language-wide (not gender-filtered) via
    /// ``VoiceSelector/hasNaturalVoice(forLanguage:in:)``: once *any* natural
    /// voice is installed the download is done and the gender picker is the
    /// remaining lever, so the download nudge would just be noise.
    public var shouldShowDownloadVoiceTip: Bool {
        guard let voicePreviewer, !downloadVoiceTipDismissed else { return false }
        let catalog = voicePreviewer.installedVoices()
        guard !catalog.isEmpty else { return false }
        return !VoiceSelector.hasNaturalVoice(forLanguage: voiceLanguageCode, in: catalog)
    }

    /// Backing read of the dismissal flag (AC-40.13 / CL-123). Absent key →
    /// false (tip eligible).
    public var downloadVoiceTipDismissed: Bool {
        defaults.bool(forKey: Self.downloadVoiceTipDismissedKey)
    }

    /// Permanently dismiss the download-a-better-voice tip (CL-123). Called by
    /// the tip's close control; the nudge never re-shows afterward.
    public func dismissDownloadVoiceTip() {
        defaults.set(true, forKey: Self.downloadVoiceTipDismissedKey)
    }

    /// Speak the sample line with the current gender pick through the injected
    /// previewer (AC-40.12). No-op when no previewer is wired (preview /
    /// snapshot host) so the button is inert rather than crashing in design
    /// surfaces. The previewer resolves the *same* voice Cook Mode would, so
    /// the user hears the real thing.
    public func previewVoice() {
        guard let voicePreviewer else { return }
        voicePreviewer.speakPreview(
            Self.voicePreviewSampleLine,
            languageCode: voiceLanguageCode,
            preference: VoicePreference(gender: voiceGender, voiceIdentifier: voiceIdentifier)
        )
    }

    /// Stop any in-flight preview — called when the voice section disappears so
    /// a preview never trails off-screen.
    public func stopVoicePreview() {
        voicePreviewer?.stopPreview()
    }
}

// MARK: - Quality tier display copy (AC-40.12)

extension VoiceQuality {
    /// User-facing label for the resolved-quality readout row. Kept in the
    /// feature layer (not `DODSupport`) so the domain model stays free of UI
    /// copy — mirrors how ``VoiceGender/displayName`` + ``AppearancePreference``
    /// host their labels beside the view.
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        }
    }
}
