import DODSupport
import Foundation

/// Maps raw shopping-list ingredient lines → ``InstacartLineItem``s for the
/// "Order on Instacart" CTA (DUT-532).
///
/// Pure + deterministic + no I/O. Each line is parsed by
/// ``IngredientLineParser`` so a structured line ("1 lb chicken thighs") yields
/// a clean `name` / `quantity` / `unit`, while an unparseable line ("black
/// pepper to taste") falls back to `name = <the raw line>`. The raw line is
/// always preserved as `displayText` so Instacart shows the cook exactly what
/// their list said. Empty / whitespace-only lines are skipped.
///
/// Lives in DODNetworking (next to the client) and operates on plain `String`s
/// so it's unit-testable here without a dependency on DODFeatureSaved — the
/// feature layer feeds it the still-need rows' `ingredientText`.
public enum InstacartLineItemMapper {

    /// The default Instacart shopping-list page title.
    public static let defaultTitle = "Dutch Oven Daddy Shopping List"

    /// Map raw ingredient lines to Instacart line-items, skipping empties.
    ///
    /// For each non-empty line: `IngredientLineParser.parse(line)` →
    /// `name = parsed.name ?? line`, `quantity = parsed.quantity`,
    /// `unit = parsed.unit`, `displayText = line` (the verbatim shopping-list row).
    public static func lineItems(from lines: [String]) -> [InstacartLineItem] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let parsed = IngredientLineParser.parse(trimmed)
            return InstacartLineItem(
                name: parsed.name ?? trimmed,
                quantity: parsed.quantity,
                unit: parsed.unit,
                displayText: trimmed
            )
        }
    }
}
