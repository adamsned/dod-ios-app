#if os(iOS) && canImport(UIKit)
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("ShareFormatRouting")
struct ShareFormatRoutingTests {
    private let key = "dod.settings.shareFormat"

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: UUID().uuidString))
    }

    @Test func defaultsToPDF() throws {
        let defaults = try makeDefaults()
        #expect(RecipeDetailView.prefersImageCard(defaults) == false)
    }

    @Test func imageCardRawIsTrue() throws {
        let defaults = try makeDefaults()
        defaults.set("imageCard", forKey: key)
        #expect(RecipeDetailView.prefersImageCard(defaults))
    }

    @Test(arguments: ["linkOnly", "linkAndText"])
    func otherFormatsAreFalse(raw: String) throws {
        let defaults = try makeDefaults()
        defaults.set(raw, forKey: key)
        #expect(RecipeDetailView.prefersImageCard(defaults) == false)
    }
}
#endif
