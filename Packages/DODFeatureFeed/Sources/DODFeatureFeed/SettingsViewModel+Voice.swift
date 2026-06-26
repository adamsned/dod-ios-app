import DODSupport
import Foundation

/// US-40 / AC-40.12 + AC-40.13 — the Settings Cook Mode Voice section's quality
/// readout + "install a better voice" nudge.
///
/// CL-279 / DUT-329 — there is no in-app voice/gender choice + no preview; Cook
/// Mode uses one auto-selected voice and voices are managed only in the iOS
/// Settings app, so the section is just an info readout + a prompt to Settings.
///
/// These belong in the view-model, not the view: the quality readout + the
/// nudge-visibility decision are pure functions of the installed catalog + the
/// dismissal flag, unit-tested on the macOS slice with a recording
/// `VoicePreviewing` double — no AVFoundation, no simulator (CL-109).
extension SettingsViewModel {

    /// The synthesis-quality tier of the voice Cook Mode would resolve right now
    /// for this device's language — the "are you on a robotic voice?" readout
    /// (AC-40.12). `nil` when no catalog is available (no previewer wired, or an
    /// empty catalog) so the view renders an honest "Unknown".
    public var resolvedVoiceQuality: VoiceQuality? {
        guard let voicePreviewer else { return nil }
        let catalog = voicePreviewer.installedVoices()
        guard !catalog.isEmpty else { return nil }
        guard
            let identifier = VoiceSelector.bestVoiceIdentifier(from: catalog, languageCode: voiceLanguageCode),
            let descriptor = catalog.first(where: { $0.identifier == identifier })
        else {
            return nil
        }
        return descriptor.quality
    }

    /// Whether the "install a better voice" tip should surface (AC-40.13). True
    /// only when a catalog is available, no natural (enhanced/premium) voice is
    /// installed for the device language (the best installed tier is the compact
    /// robotic one), and the user hasn't dismissed it (CL-123).
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

    /// Permanently dismiss the install-a-better-voice tip (CL-123). The nudge
    /// never re-shows afterward.
    public func dismissDownloadVoiceTip() {
        defaults.set(true, forKey: Self.downloadVoiceTipDismissedKey)
    }
}

// MARK: - Quality tier display copy (AC-40.12)

extension VoiceQuality {
    /// User-facing label for the resolved-quality readout row. Kept in the
    /// feature layer (not `DODSupport`) so the domain model stays free of UI copy.
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        }
    }
}
