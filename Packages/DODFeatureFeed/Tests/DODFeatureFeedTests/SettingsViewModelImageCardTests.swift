import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("SettingsViewModel image-card share format (DUT-1697)")
struct SettingsViewModelImageCardTests {
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelImageCardTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func shareFormatImageCardPersistsWireValue() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.shareFormat = .imageCard
        #expect(defaults.string(forKey: SettingsViewModel.shareFormatPreferenceKey) == "imageCard")
        #expect(ShareFormatPreference.fromDefaults(defaults) == .imageCard)
        #expect(ShareFormatPreference.imageCard.displayName == "Branded image card")
    }
}
