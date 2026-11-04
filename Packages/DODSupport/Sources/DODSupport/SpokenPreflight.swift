import DODDomain
import Foundation

/// DUT-990 - pure copy builder for the spoken "what do I need" preflight.
public enum SpokenPreflight {

    /// Gear every coal cook needs when the recipe lists no equipment.
    public static let fallbackGear = [
        "Dutch oven", "charcoal briquettes", "chimney starter", "lid lifter", "heat-proof gloves",
    ]

    /// - Parameters:
    ///   - title: recipe title.
    ///   - equipment: names from `Equipment.name`; blank names are dropped, an empty result falls back to `fallbackGear`.
    ///   - coals: optional recommendation from `CharcoalRecipeConverter.recommend`.
    public static func script(title: String, equipment: [String], coals: CharcoalRecommendation?) -> String {
        let names = equipment.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let gear = names.isEmpty ? fallbackGear : names
        var text = "For \(title) you need \(spokenList(gear))."
        if let coals, coals.totalBriquettes > 0 {
            text +=
                " Plan on about \(coals.totalBriquettes) briquettes, \(coals.bottom) under the oven and \(coals.top) on the lid."
        }
        return text
    }

    /// "a" / "a and b" / "a, b, and c".
    static func spokenList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }
}
