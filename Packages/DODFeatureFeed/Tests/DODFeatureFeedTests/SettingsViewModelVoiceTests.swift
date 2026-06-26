import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the Settings → Cook Mode Voice view-model surface (US-40 /
/// AC-40.12).
///
/// CL-279 / DUT-329 — Cook Mode uses ONE auto-selected voice (no in-app picker /
/// gender). DUT-332/333 — the surface is the resolved-voice name readout
/// ("Voice: <name>") + a preview; DUT-334 removed the in-Settings download popup.
/// Asserted on the macOS slice with a recording `VoicePreviewing` double — no
/// AVFoundation, no simulator (CL-109).
@MainActor
@Suite("SettingsViewModel voice (US-40 / DUT-332)") struct SettingsViewModelVoiceTests {

    /// Fresh, per-test `UserDefaults` suite so a write in one test never leaks
    /// into another (mirrors ``SettingsViewModelTests``).
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelVoiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(resolvedName: String?) -> (SettingsViewModel, RecordingVoicePreviewer) {
        let previewer = RecordingVoicePreviewer(catalog: [], resolvedName: resolvedName)
        let viewModel = SettingsViewModel(
            defaults: Self.isolatedDefaults(),
            voicePreviewer: previewer,
            voiceLocale: Locale(identifier: "en-US")
        )
        return (viewModel, previewer)
    }

    // MARK: - Resolved-voice readout (DUT-332 / DUT-333)

    @Test func displayShowsTheResolvedVoiceName() {
        // Apple's name already carries the tier for natural voices; we show it
        // verbatim and never append our own (which double-tagged it — DUT-333).
        let (viewModel, _) = makeViewModel(resolvedName: "Jamie (Premium)")
        #expect(viewModel.resolvedVoiceDisplay == "Voice: Jamie (Premium)")
    }

    @Test func displayShowsABareCompactNameWithoutATier() {
        // Compact voices have no parenthetical in Apple's name — shown as-is.
        let (viewModel, _) = makeViewModel(resolvedName: "Samantha")
        #expect(viewModel.resolvedVoiceDisplay == "Voice: Samantha")
    }

    @Test func displayIsUnknownWhenNoNameResolves() {
        let (viewModel, _) = makeViewModel(resolvedName: nil)
        #expect(viewModel.resolvedVoiceDisplay == "Voice: Unknown")
    }

    @Test func displayIsUnknownWithNoPreviewer() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(viewModel.resolvedVoiceDisplay == "Voice: Unknown")
    }

    // MARK: - Preview (DUT-332)

    @Test func previewVoiceForwardsToTheSeam() {
        let (viewModel, previewer) = makeViewModel(resolvedName: "Jamie (Premium)")
        viewModel.previewVoice()
        #expect(previewer.previewCount == 1)
    }
}

/// A recording `VoicePreviewing` double. Top-level so both
/// `SettingsViewModelVoiceTests` and `SettingsViewSnapshotTests` share it.
@MainActor
final class RecordingVoicePreviewer: VoicePreviewing {
    let catalog: [VoiceDescriptor]
    let resolvedName: String?
    private(set) var previewCount = 0

    init(catalog: [VoiceDescriptor], resolvedName: String? = nil) {
        self.catalog = catalog
        self.resolvedName = resolvedName
    }

    func installedVoices() -> [VoiceDescriptor] { catalog }
    func resolvedVoiceName(languageCode: String?) -> String? { resolvedName }
    func previewVoice(languageCode: String?) { previewCount += 1 }
}
