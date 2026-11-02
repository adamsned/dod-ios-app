import Foundation

/// Decides whether a model `IngredientParse` may override the heuristic
/// `IngredientLineParser` result for a line (DUT-1020). Conservative: the
/// model never invents or changes a quantity the heuristic already read.
public enum IngredientParseGate {

    /// - Returns: the model parse as a `ParsedIngredientLine` when trusted,
    ///   otherwise the heuristic result.
    public static func resolve(text: String, model: IngredientParse?) -> ParsedIngredientLine {
        let heuristic = IngredientLineParser.parse(text)
        guard let model, let candidate = model.asParsedLine(originalText: text) else { return heuristic }
        if let hq = heuristic.quantity {
            // Heuristic read a leading quantity: model must agree (±0.01).
            guard let mq = candidate.quantity, abs(mq - hq) < 0.01 else { return heuristic }
            return candidate
        }
        // Heuristic found none (e.g. "salt to taste"): accept a model quantity
        // only if the line visibly contains a digit or vulgar fraction.
        if candidate.quantity != nil, !containsNumeral(text) {
            // When the text has no numerals but the model has a quantity,
            // we should still use the model's name but the heuristic's quantity (nil)
            return ParsedIngredientLine(
                originalText: heuristic.originalText,
                quantity: heuristic.quantity,
                unit: candidate.unit,
                name: candidate.name
            )
        }
        return candidate
    }

    private static func containsNumeral(_ text: String) -> Bool {
        text.contains { $0.isNumber }  // isNumber covers ½ ¼ etc.
    }
}
