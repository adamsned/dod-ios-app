import Foundation

#if os(iOS)
import FoundationModels
#endif

// On-device guided generation for one ingredient line (DUT-1020 / DUT-1806).
// iOS-26-only: everything model-related is inside `#if os(iOS)` + `@available(iOS 26, *)`.
extension LiveDODIntelligenceService {

    #if os(iOS)
    /// FoundationModels-native mirror of `IngredientParse`; mapped onto the plain
    /// type before returning so the framework never escapes this unit.
    @available(iOS 26, *)
    @Generable
    struct GenerableIngredientParse {
        @Guide(description: "Numeric amount exactly as written, e.g. 1.5 for '1 1/2'. Omit if the line has no number.")
        var quantity: Double?
        @Guide(description: "Unit as written, e.g. cup, tbsp, clove. Omit if none.")
        var unit: String?
        @Guide(description: "The ingredient itself without amount or preparation, e.g. 'yellow onion'.")
        var item: String
        @Guide(description: "Preparation notes such as 'finely chopped' or 'to taste'. Omit if none.")
        var prep: String?
    }
    #endif
}
