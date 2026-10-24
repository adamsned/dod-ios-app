import Foundation
import Testing

@testable import DODSupport

/// DUT-131 — persisted "Keep saved recipes available offline" toggle.
@Suite("OfflineSettings (DUT-131)")
struct OfflineSettingsTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "OfflineSettingsTests-\(UUID().uuidString)") ?? .standard
    }

    @Test func defaultsToOff() {
        let defaults = makeDefaults()
        #expect(OfflineSettings(defaults: defaults).keepSavedRecipesOffline == false)
    }

    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = OfflineSettings(defaults: defaults)
        first.keepSavedRecipesOffline = true
        let second = OfflineSettings(defaults: defaults)
        #expect(second.keepSavedRecipesOffline == true)
    }
}
