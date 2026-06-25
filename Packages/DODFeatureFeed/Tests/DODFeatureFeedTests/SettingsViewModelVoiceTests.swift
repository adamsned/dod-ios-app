import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the Cook Mode voice-gender preference exposed through
/// ``SettingsViewModel`` (T-721, the Phase-b Settings picker for US-40's
/// voice-quality engine). Verifies the view-model is a faithful, isolated
/// front-end over ``VoicePreferenceStore`` — the same store the recipe-detail
/// read-aloud engine reads — so flipping the picker actually changes the
/// voice the next time Cook Mode resolves one.
///
/// Spec trace: US-40 AC-40.10 (gender-primary selection honors the stored
/// preference) / AC-40.11 (canonical key `dod.voice.preferredGenderV1`,
/// default `.female`, unknown value falls back to `.female`).
@MainActor
@Suite("SettingsViewModel voice picker (T-721)") struct SettingsViewModelVoiceTests {

    /// Fresh, per-test `UserDefaults` suite so a write in one test never
    /// leaks into another (mirrors ``SettingsViewModelTests``).
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelVoiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultGenderIsFemaleOnFreshDefaults() async throws {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        // AC-40.11 — unset key resolves to `.female` (the platform-default
        // voice, en-US Samantha), so the picker opens on a sensible value.
        #expect(viewModel.voiceGender == .female)
    }

    @Test func settingGenderPersistsToCanonicalKey() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.voiceGender = .male
        #expect(viewModel.voiceGender == .male)
        // Round-trip through the EXACT key the read-aloud engine reads
        // (AC-40.11) — the store persists the lowercase case name.
        #expect(defaults.string(forKey: VoicePreferenceStore.genderKey) == "male")

        viewModel.voiceGender = .unspecified
        #expect(defaults.string(forKey: VoicePreferenceStore.genderKey) == "unspecified")
    }

    @Test func newViewModelReadsBackPersistedGender() async throws {
        let defaults = Self.isolatedDefaults()
        SettingsViewModel(defaults: defaults).voiceGender = .male

        // A fresh view-model over the same suite observes the persisted
        // choice — the picker reflects prior selection across launches.
        #expect(SettingsViewModel(defaults: defaults).voiceGender == .male)
    }

    @Test func unknownStoredValueFallsBackToFemale() async throws {
        let defaults = Self.isolatedDefaults()
        // A value the store doesn't recognize (forward-compat / corruption)
        // must degrade to `.female`, never crash or surface a phantom case.
        defaults.set("klingon", forKey: VoicePreferenceStore.genderKey)
        #expect(SettingsViewModel(defaults: defaults).voiceGender == .female)
    }

    @Test func everyGenderRoundTrips() async throws {
        for gender in VoiceGender.allCases {
            let defaults = Self.isolatedDefaults()
            let viewModel = SettingsViewModel(defaults: defaults)
            viewModel.voiceGender = gender
            #expect(viewModel.voiceGender == gender)
            #expect(SettingsViewModel(defaults: defaults).voiceGender == gender)
        }
    }

    // MARK: - Quality readout (AC-40.12)

    /// Convenience: a view-model wired to a recording previewer over an
    /// en-US locale and an isolated defaults suite.
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

    private func voice(
        _ id: String,
        _ gender: VoiceGender,
        _ quality: VoiceQuality,
        lang: String = "en-US"
    ) -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, languageCode: lang, gender: gender, quality: quality)
    }

    @Test func qualityReadoutReflectsResolvedTierForPreferredGender() {
        // Default pref is female. With an enhanced female + compact male
        // installed, the resolved tier for the (default) female pick is
        // Enhanced — the user is NOT on a robotic voice.
        let (viewModel, _) = makeViewModel(catalog: [
            voice("female.enhanced", .female, .enhanced),
            voice("male.compact", .male, .default),
        ])
        #expect(viewModel.resolvedVoiceQuality == .enhanced)
    }

    @Test func qualityReadoutStaysNaturalAcrossGenderFlip() {
        // DUT-327 — natural-first. Enhanced female + only-compact male installed.
        // Flipping the gender pick to Male does NOT drop to the robotic tier (the
        // old gender-primary behavior, the bug): the enhanced voice still wins,
        // so the readout stays Enhanced. "Don't sound like a robot" beats gender.
        let (viewModel, _) = makeViewModel(catalog: [
            voice("female.enhanced", .female, .enhanced),
            voice("male.compact", .male, .default),
        ])
        #expect(viewModel.resolvedVoiceQuality == .enhanced)

        viewModel.voiceGender = .male
        #expect(viewModel.resolvedVoiceQuality == .enhanced)
    }

    @Test func qualityReadoutReflectsExplicitPick() {
        // DUT-327 — an explicit pick wins, even a deliberately-robotic one: the
        // readout shows the tier of the voice the user actually wired in.
        let (viewModel, _) = makeViewModel(catalog: [
            voice("female.enhanced", .female, .enhanced),
            voice("male.compact", .male, .default),
        ])
        #expect(viewModel.resolvedVoiceQuality == .enhanced)

        viewModel.voiceIdentifier = "male.compact"
        #expect(viewModel.resolvedVoiceQuality == .default)
    }

    @Test func installedVoiceChoicesListNaturalFirst() {
        // DUT-327 — the picker's voice list returns the language-matched voices
        // best-sounding first (premium, then enhanced, then compact).
        let (viewModel, _) = makeViewModel(catalog: [
            voice("male.compact", .male, .default),
            voice("female.premium", .female, .premium),
            voice("female.enhanced", .female, .enhanced),
        ])
        let ids = viewModel.installedVoiceChoices.map(\.identifier)
        #expect(ids == ["female.premium", "female.enhanced", "male.compact"])
    }

    @Test func voiceIdentifierPersistsAcrossViewModels() {
        // The explicit pick round-trips through the store like the gender pick.
        let defaults = Self.isolatedDefaults()
        let (first, _) = makeViewModel(catalog: [], defaults: defaults)
        first.voiceIdentifier = "com.apple.voice.enhanced.en-US.Evan"
        let (second, _) = makeViewModel(catalog: [], defaults: defaults)
        #expect(second.voiceIdentifier == "com.apple.voice.enhanced.en-US.Evan")
    }

    @Test func qualityReadoutIsNilWithNoPreviewer() {
        // No previewer wired (preview / snapshot host) → no catalog → nil, so
        // the view renders an honest "Unknown" rather than a guessed tier.
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(viewModel.resolvedVoiceQuality == nil)
    }

    @Test func qualityReadoutIsNilWithEmptyCatalog() {
        let (viewModel, _) = makeViewModel(catalog: [])
        #expect(viewModel.resolvedVoiceQuality == nil)
    }

    // MARK: - Download nudge visibility (AC-40.13)

    @Test func nudgeShowsWhenOnlyCompactInstalled() {
        // The stock-device case: only the compact voice for en-US is installed,
        // tip not dismissed → the nudge surfaces.
        let (viewModel, _) = makeViewModel(catalog: [
            voice("female.compact", .female, .default)
        ])
        #expect(viewModel.shouldShowDownloadVoiceTip)
    }

    @Test func nudgeHiddenWhenEnhancedInstalled() {
        // Any natural voice (either gender) installed → the download is done,
        // so the nudge stays hidden even though the gender picker still applies.
        let (viewModel, _) = makeViewModel(catalog: [
            voice("female.compact", .female, .default),
            voice("male.enhanced", .male, .enhanced),
        ])
        #expect(!viewModel.shouldShowDownloadVoiceTip)
    }

    @Test func nudgeHiddenAfterDismissAndPersists() {
        let defaults = Self.isolatedDefaults()
        let (viewModel, _) = makeViewModel(
            catalog: [voice("female.compact", .female, .default)],
            defaults: defaults
        )
        #expect(viewModel.shouldShowDownloadVoiceTip)

        viewModel.dismissDownloadVoiceTip()
        #expect(!viewModel.shouldShowDownloadVoiceTip)
        #expect(viewModel.downloadVoiceTipDismissed)

        // CL-123: dismissal persists — a fresh view-model over the same suite
        // (next app launch) still suppresses the nudge even with a compact-only
        // catalog.
        let previewer = RecordingVoicePreviewer(catalog: [voice("female.compact", .female, .default)])
        let relaunched = SettingsViewModel(
            defaults: defaults,
            voicePreviewer: previewer,
            voiceLocale: Locale(identifier: "en-US")
        )
        #expect(!relaunched.shouldShowDownloadVoiceTip)
    }

    @Test func nudgeHiddenWithNoPreviewerOrEmptyCatalog() {
        // No catalog signal → never surface a false "you're on a robotic
        // voice" nudge.
        let noPreviewer = SettingsViewModel(defaults: Self.isolatedDefaults())
        #expect(!noPreviewer.shouldShowDownloadVoiceTip)

        let (emptyCatalog, _) = makeViewModel(catalog: [])
        #expect(!emptyCatalog.shouldShowDownloadVoiceTip)
    }

    // MARK: - Preview trigger (AC-40.12)

    @Test func previewVoiceSpeaksSampleLineWithCurrentPick() {
        let (viewModel, previewer) = makeViewModel(catalog: [
            voice("female.enhanced", .female, .enhanced)
        ])
        viewModel.voiceGender = .female

        viewModel.previewVoice()

        #expect(previewer.spokenSamples.count == 1)
        let sample = previewer.spokenSamples.first
        #expect(sample?.text == SettingsViewModel.voicePreviewSampleLine)
        #expect(sample?.languageCode == "en")
        #expect(sample?.preference == VoicePreference(gender: .female))
    }

    @Test func previewVoicePassesUpdatedGenderAfterFlip() {
        let (viewModel, previewer) = makeViewModel(catalog: [
            voice("male.enhanced", .male, .enhanced)
        ])
        viewModel.voiceGender = .male

        viewModel.previewVoice()

        #expect(previewer.spokenSamples.last?.preference == VoicePreference(gender: .male))
    }

    @Test func previewVoiceIsNoOpWithoutPreviewer() {
        // No previewer wired → inert, never crashes (design-surface safety).
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults())
        viewModel.previewVoice()  // must not trap
        #expect(viewModel.resolvedVoiceQuality == nil)
    }

    @Test func stopVoicePreviewForwardsToPreviewer() {
        let (viewModel, previewer) = makeViewModel(catalog: [
            voice("female.enhanced", .female, .enhanced)
        ])
        viewModel.previewVoice()
        viewModel.stopVoicePreview()
        #expect(previewer.stopCount == 1)
    }
}

// MARK: - Recording VoicePreviewing double

/// In-memory ``VoicePreviewing`` that records what it was asked to speak +
/// vends a fixed catalog, so the SettingsViewModel voice logic is asserted
/// with zero AVFoundation / real-audio dependency (mirrors the
/// `MockSpeechSynthesizer` pattern in `VoiceReaderTests`).
@MainActor
final class RecordingVoicePreviewer: VoicePreviewing {

    struct Sample: Equatable {
        let text: String
        let languageCode: String?
        let preference: VoicePreference
    }

    private let catalog: [VoiceDescriptor]
    private(set) var spokenSamples: [Sample] = []
    private(set) var stopCount = 0

    init(catalog: [VoiceDescriptor]) {
        self.catalog = catalog
    }

    func installedVoices() -> [VoiceDescriptor] { catalog }

    func speakPreview(_ text: String, languageCode: String?, preference: VoicePreference) {
        spokenSamples.append(Sample(text: text, languageCode: languageCode, preference: preference))
    }

    func stopPreview() {
        stopCount += 1
    }
}
