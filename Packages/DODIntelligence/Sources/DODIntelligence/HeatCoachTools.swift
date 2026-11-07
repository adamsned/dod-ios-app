import DODSupport
import Foundation

/// Platform-neutral core of the coal-adjustment tool. Always compiled so it is
/// unit-testable on macOS; the FoundationModels `Tool` wrapper is added in a later piece.
enum HeatCoachToolCore {
    /// Maps the model's free-text ambient argument to a condition; unknown text is mild.
    static func ambientCondition(from text: String) -> AmbientCondition {
        switch text.lowercased() {
        case "hot": return .hot
        case "cold": return .cold
        default: return .mild
        }
    }

    static func adjustment(
        ovenDiameterInches: Int,
        isBaking: Bool,
        ambient: String,
        windy: Bool,
        elevationFeet: Int,
        publishedAt: Date = Date()
    ) -> String {
        DutchOvenHeatCoach.groundedFacts(
            ovenDiameterInches: ovenDiameterInches,
            style: isBaking ? .baking : .even,
            ambient: ambientCondition(from: ambient),
            windy: windy,
            elevationFeet: elevationFeet
        ).summary
    }
}
