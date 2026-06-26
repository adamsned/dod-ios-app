import DODSupport
import Foundation

/// US-40 / AC-40.12 (DUT-332) — the Settings Cook Mode Voice section's
/// resolved-voice readout + preview.
///
/// CL-279 / DUT-329 — there is no in-app voice/gender choice; Cook Mode uses one
/// auto-selected voice and voices are managed only in the iOS Settings app.
/// DUT-332 names the resolved voice + previews it; DUT-334 — where to download
/// voices is stated in the section footer, not a popup. These belong in the
/// view-model, not the view: pure functions of the `VoicePreviewing` seam,
/// unit-tested on the macOS slice with a recording double (CL-79 / CL-109).
extension SettingsViewModel {

    /// DUT-332 / DUT-333 — the Settings readout: "Voice: <name>" naming the voice
    /// Cook Mode resolves for this device (e.g. "Voice: Jamie (Premium)"). Apple's
    /// voice name already carries the quality tier for Enhanced/Premium voices, so
    /// we show it verbatim and never append our own tier (that double-tagged it).
    /// "Voice: Unknown" when no name is available (e.g. the test double / no live
    /// catalog).
    public var resolvedVoiceDisplay: String {
        guard let name = voicePreviewer?.resolvedVoiceName(languageCode: voiceLanguageCode) else {
            return "Voice: Unknown"
        }
        return "Voice: \(name)"
    }

    /// DUT-332 — speak a sample line in the resolved voice (the cell's speaker
    /// button), so the user can hear their selected voice from Settings.
    public func previewVoice() {
        voicePreviewer?.previewVoice(languageCode: voiceLanguageCode)
    }
}
