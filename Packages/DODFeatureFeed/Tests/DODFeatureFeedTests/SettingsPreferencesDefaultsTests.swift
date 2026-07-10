import SwiftUI
import Testing

@testable import DODFeatureFeed

@Suite
struct SettingsPreferencesDefaultsTests {
    // MARK: - AppearancePreference displayName

    @Test("AppearancePreference.displayName for .system")
    func appearanceDisplayNameSystem() {
        #expect(AppearancePreference.system.displayName == "Match System")
    }

    @Test("AppearancePreference.displayName for .light")
    func appearanceDisplayNameLight() {
        #expect(AppearancePreference.light.displayName == "Flour")
    }

    @Test("AppearancePreference.displayName for .dark")
    func appearanceDisplayNameDark() {
        #expect(AppearancePreference.dark.displayName == "Cocoa")
    }

    // MARK: - AppearancePreference colorScheme

    @Test("AppearancePreference.colorScheme for .system")
    func appearanceColorSchemeSystem() {
        #expect(AppearancePreference.system.colorScheme == nil)
    }

    @Test("AppearancePreference.colorScheme for .light")
    func appearanceColorSchemeLight() {
        #expect(AppearancePreference.light.colorScheme == .light)
    }

    @Test("AppearancePreference.colorScheme for .dark")
    func appearanceColorSchemeDark() {
        #expect(AppearancePreference.dark.colorScheme == .dark)
    }

    // MARK: - AppearancePreference fromDefaults

    @Test("AppearancePreference.fromDefaults with valid .system raw value")
    func appearanceFromDefaultsValidSystem() {
        let suiteName = "test-appearance-system-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(AppearancePreference.system.rawValue, forKey: SettingsViewModel.appearancePreferenceKey)
        let result = AppearancePreference.fromDefaults(defaults)
        #expect(result == .system)
    }

    @Test("AppearancePreference.fromDefaults with valid .light raw value")
    func appearanceFromDefaultsValidLight() {
        let suiteName = "test-appearance-light-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(AppearancePreference.light.rawValue, forKey: SettingsViewModel.appearancePreferenceKey)
        let result = AppearancePreference.fromDefaults(defaults)
        #expect(result == .light)
    }

    @Test("AppearancePreference.fromDefaults with valid .dark raw value")
    func appearanceFromDefaultsValidDark() {
        let suiteName = "test-appearance-dark-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(AppearancePreference.dark.rawValue, forKey: SettingsViewModel.appearancePreferenceKey)
        let result = AppearancePreference.fromDefaults(defaults)
        #expect(result == .dark)
    }

    @Test("AppearancePreference.fromDefaults with absent key returns safe default")
    func appearanceFromDefaultsAbsentKey() {
        let suiteName = "test-appearance-absent-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        // Don't set anything; key is absent
        let result = AppearancePreference.fromDefaults(defaults)
        #expect(result == .system, "Absent key should fall back to .system")
    }

    @Test("AppearancePreference.fromDefaults with malformed raw value returns safe default (DUT-62)")
    func appearanceFromDefaultsMalformed() {
        let suiteName = "test-appearance-malformed-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set("garbage_invalid_preference", forKey: SettingsViewModel.appearancePreferenceKey)
        let result = AppearancePreference.fromDefaults(defaults)
        #expect(result == .system, "Malformed value should fall back to .system, not crash")
    }

    // MARK: - ShareFormatPreference displayName

    @Test("ShareFormatPreference.displayName for .linkOnly")
    func shareFormatDisplayNameLinkOnly() {
        #expect(ShareFormatPreference.linkOnly.displayName == "Just the link")
    }

    @Test("ShareFormatPreference.displayName for .linkAndText")
    func shareFormatDisplayNameLinkAndText() {
        #expect(ShareFormatPreference.linkAndText.displayName == "Link + recipe text")
    }

    // MARK: - ShareFormatPreference fromDefaults

    @Test("ShareFormatPreference.fromDefaults with valid .linkOnly raw value")
    func shareFormatFromDefaultsValidLinkOnly() {
        let suiteName = "test-shareformat-linkonly-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(ShareFormatPreference.linkOnly.rawValue, forKey: SettingsViewModel.shareFormatPreferenceKey)
        let result = ShareFormatPreference.fromDefaults(defaults)
        #expect(result == .linkOnly)
    }

    @Test("ShareFormatPreference.fromDefaults with valid .linkAndText raw value")
    func shareFormatFromDefaultsValidLinkAndText() {
        let suiteName = "test-shareformat-linkandtext-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(ShareFormatPreference.linkAndText.rawValue, forKey: SettingsViewModel.shareFormatPreferenceKey)
        let result = ShareFormatPreference.fromDefaults(defaults)
        #expect(result == .linkAndText)
    }

    @Test("ShareFormatPreference.fromDefaults with absent key returns safe default")
    func shareFormatFromDefaultsAbsentKey() {
        let suiteName = "test-shareformat-absent-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        let result = ShareFormatPreference.fromDefaults(defaults)
        #expect(result == .linkOnly, "Absent key should fall back to .linkOnly")
    }

    @Test("ShareFormatPreference.fromDefaults with malformed raw value returns safe default (DUT-62)")
    func shareFormatFromDefaultsMalformed() {
        let suiteName = "test-shareformat-malformed-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set("garbage_invalid_shareformat", forKey: SettingsViewModel.shareFormatPreferenceKey)
        let result = ShareFormatPreference.fromDefaults(defaults)
        #expect(result == .linkOnly, "Malformed value should fall back to .linkOnly, not crash")
    }

    // MARK: - TemperaturePreference displayName

    @Test("TemperaturePreference.displayName for .recipeDefault")
    func temperatureDisplayNameRecipeDefault() {
        #expect(TemperaturePreference.recipeDefault.displayName == "Recipe Default")
    }

    @Test("TemperaturePreference.displayName for .fahrenheit")
    func temperatureDisplayNameFahrenheit() {
        #expect(TemperaturePreference.fahrenheit.displayName == "Fahrenheit")
    }

    @Test("TemperaturePreference.displayName for .celsius")
    func temperatureDisplayNameCelsius() {
        #expect(TemperaturePreference.celsius.displayName == "Celsius")
    }

    // MARK: - TemperaturePreference targetUnit

    @Test("TemperaturePreference.targetUnit for .recipeDefault")
    func temperatureTargetUnitRecipeDefault() {
        #expect(TemperaturePreference.recipeDefault.targetUnit == nil)
    }

    @Test("TemperaturePreference.targetUnit for .fahrenheit")
    func temperatureTargetUnitFahrenheit() {
        #expect(TemperaturePreference.fahrenheit.targetUnit == .fahrenheit)
    }

    @Test("TemperaturePreference.targetUnit for .celsius")
    func temperatureTargetUnitCelsius() {
        #expect(TemperaturePreference.celsius.targetUnit == .celsius)
    }

    // MARK: - TemperaturePreference fromDefaults

    @Test("TemperaturePreference.fromDefaults with valid .recipeDefault raw value")
    func temperatureFromDefaultsValidRecipeDefault() {
        let suiteName = "test-temperature-default-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(TemperaturePreference.recipeDefault.rawValue, forKey: SettingsViewModel.temperaturePreferenceKey)
        let result = TemperaturePreference.fromDefaults(defaults)
        #expect(result == .recipeDefault)
    }

    @Test("TemperaturePreference.fromDefaults with valid .fahrenheit raw value")
    func temperatureFromDefaultsValidFahrenheit() {
        let suiteName = "test-temperature-fahrenheit-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(TemperaturePreference.fahrenheit.rawValue, forKey: SettingsViewModel.temperaturePreferenceKey)
        let result = TemperaturePreference.fromDefaults(defaults)
        #expect(result == .fahrenheit)
    }

    @Test("TemperaturePreference.fromDefaults with valid .celsius raw value")
    func temperatureFromDefaultsValidCelsius() {
        let suiteName = "test-temperature-celsius-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set(TemperaturePreference.celsius.rawValue, forKey: SettingsViewModel.temperaturePreferenceKey)
        let result = TemperaturePreference.fromDefaults(defaults)
        #expect(result == .celsius)
    }

    @Test("TemperaturePreference.fromDefaults with absent key returns safe default")
    func temperatureFromDefaultsAbsentKey() {
        let suiteName = "test-temperature-absent-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        let result = TemperaturePreference.fromDefaults(defaults)
        #expect(result == .recipeDefault, "Absent key should fall back to .recipeDefault")
    }

    @Test("TemperaturePreference.fromDefaults with malformed raw value returns safe default (DUT-62)")
    func temperatureFromDefaultsMalformed() {
        let suiteName = "test-temperature-malformed-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false), "Failed to create isolated UserDefaults")
            return
        }

        defaults.set("garbage_invalid_temperature", forKey: SettingsViewModel.temperaturePreferenceKey)
        let result = TemperaturePreference.fromDefaults(defaults)
        #expect(result == .recipeDefault, "Malformed value should fall back to .recipeDefault, not crash")
    }
}
