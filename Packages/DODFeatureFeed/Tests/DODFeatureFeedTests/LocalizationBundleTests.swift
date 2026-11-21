import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("Localization bundle") struct LocalizationBundleTests {
    @Test func spanishCatalogResolves() {
        // `locale:` only affects formatting, so resolve through the es.lproj bundle.
        let path = feedBundle.path(forResource: "es", ofType: "lproj")
        let esBundle = path.flatMap { Bundle(path: $0) }
        let value = esBundle?.localizedString(forKey: "App Appearance", value: nil, table: nil)
        #expect(value == "Apariencia de la app")
    }
}
