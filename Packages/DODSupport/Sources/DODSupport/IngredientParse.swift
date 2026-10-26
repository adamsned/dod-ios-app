import Foundation

/// Structured parse of one `RecipeIngredient.text` line (DUT-1020). Plain value
/// type; the on-device model produces a `@Generable` mirror that maps onto it.
public struct IngredientParse: Sendable, Equatable {
    public let quantity: Double?
    public let unit: String?
    public let item: String
    public let prep: String?

    public init(quantity: Double?, unit: String?, item: String, prep: String?) {
        self.quantity = quantity
        self.unit = unit
        self.item = item
        self.prep = prep
    }
}

extension IngredientParse {
    /// Bridge to the aggregator's existing parsed shape. The unit is passed
    /// through `IngredientLineParser.canonicalUnit(_:)` so "cups"/"Tbsp" merge
    /// with heuristic-parsed lines. Returns nil when `item` is blank.
    func asParsedLine(originalText: String) -> ParsedIngredientLine? {
        let name = item.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let canonical = unit.flatMap { IngredientLineParser.canonicalUnit($0) }
        return ParsedIngredientLine(originalText: originalText, quantity: quantity, unit: canonical, name: name)
    }
}
