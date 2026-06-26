import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the Settings → Cook Mode Voice view-model surface
/// (US-40 / AC-40.12 + AC-40.13).
///
/// CL-279 / DUT-329 — Cook Mode uses ONE auto-selected voice; there is no in-app
/// voice or gender choice (the gender + per-voice pickers were removed). So the
/// view-model surface is just the resolved-quality readout + the
/// "install a better voice" nudge gate, asserted on the macOS slice with a
/// recording `VoicePreviewing` double — no AVFoundation, no simulator (CL-109).
@MainActor
@Suite("SettingsViewModel voice (US-40 / DUT-329)") struct SettingsViewModelVoiceTests {

    /// Fresh, per-test `UserDefaults` suite so a write in one test never leaks
    /// into another (mirrors ``SettingsViewModelTests``).
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelVoiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func voice(_ id: String, _ quality: VoiceQuality, lang: String = "en-US") -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, languageCode: lang, quality: quality)
    }

    private func makeViewModel(
        catalog: [VoiceDescriptor],
        defaults: UserDefaults? = nil
    ) -> (SettingsViewModel, RecordingVoicePreviewer) {
        let previewer = RecordingVoicePreviewer(catalog: catalog)
        let viewModel = SettingsViewModel(
            defaults: defaults ?? Self.isolatedDefaults(),
            voicePreviewer: previewer,
            voiceLocale: Locale(identifier: "en-US")
        )
        return (viewModel, previewer)
    }

    // MARK: - Resolved quality readout (AC-40.12)

    @Test func resolvedQualityIsTheBestInstalledTier() {
        let (viewModel, _) = makeViewModel(catalog: [
            voice("compact", .default),
            voice("enhanced", .enhanced),
        ])
        #expect(viewModel.resolvedVoiceQuality == .enhanced)
    }

    @Test func resolvedQualityIsDefaultWhenOnlyCompactInstalled() {
        let (viewModel, _) = makeViewModel(catalog: [voice("compact", .default)])
        #expect(viewModel.resolvedVoiceQuality == .default)
    }

    @Test func resolvedQualityIsNilWithNoPreviewer() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(viewModel.resolvedVoiceQuality == nil)
    }

    @Test func resolvedQualityIsNilWithEmptyCatalog() {
        let (viewModel, _) = makeViewModel(catalog: [])
        #expect(viewModel.resolvedVoiceQuality == nil)
    }

    // MARK: - Install-a-better-voice nudge (AC-40.13)

    @Test func tipShowsWhenOnlyCompactInstalled() {
        let (viewModel, _) = makeViewModel(catalog: [voice("compact", .default)])
        #expect(viewModel.shouldShowDownloadVoiceTip)
    }

    @Test func tipHiddenWhenNaturalVoiceInstalled() {
        let (viewModel, _) = makeViewModel(catalog: [
            voice("compact", .default),
            voice("enhanced", .enhanced),
        ])
        #expect(!viewModel.shouldShowDownloadVoiceTip)
    }

    @Test func tipHiddenAfterDismissal() {
        let (viewModel, _) = makeViewModel(catalog: [voice("compact", .default)])
        #expect(viewModel.shouldShowDownloadVoiceTip)
        viewModel.dismissDownloadVoiceTip()
        #expect(!viewModel.shouldShowDownloadVoiceTip)
        #expect(viewModel.downloadVoiceTipDismissed)
    }

    @Test func tipHiddenWithNoPreviewer() {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(!viewModel.shouldShowDownloadVoiceTip)
    }

    @Test func tipHiddenWithEmptyCatalog() {
        let (viewModel, _) = makeViewModel(catalog: [])
        #expect(!viewModel.shouldShowDownloadVoiceTip)
    }
}

/// A recording `VoicePreviewing` double — returns a fixed installed catalog.
/// Top-level so both `SettingsViewModelVoiceTests` and `SettingsViewSnapshotTests`
/// share it (DUT-329 — the seam now carries only the catalog read).
@MainActor
final class RecordingVoicePreviewer: VoicePreviewing {
    let catalog: [VoiceDescriptor]
    init(catalog: [VoiceDescriptor]) { self.catalog = catalog }
    func installedVoices() -> [VoiceDescriptor] { catalog }
}
