import DODDomain
import Foundation

/// Combines a flat list of recipe-ingredient lines into a deduplicated,
/// aisle-tagged shopping list, summing quantities **only** where the unit and
/// the ingredient name match.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping — every result carries its
/// classified ``IngredientAisleClassifier/Aisle``), AC-39.7 (an optional
/// rolled-up share-text path), AC-39.12 (pure on-device — no view, no
/// persistence, no network). CL-70 (same-unit summation, option (b)), CL-77
/// (the v1 *shipped UI* keeps per-recipe rows; this aggregator is a reusable
/// capability, not a change to that contract), CL-79 (the logic-core split).
/// Constitution §6 L1 mandate (every domain transform owns tests).
///
/// **What it merges:** two lines merge into one ``AggregatedItem`` when (a)
/// both have a parseable leading quantity, (b) their units match (case- and
/// plural-insensitively — `cup` ≡ `cups`), and (c) their remaining names
/// match (case-insensitively, whitespace-collapsed). `"2 cups flour"` +
/// `"1 cup flour"` → `"3 cups flour"`; `"½ cup sugar"` + `"¼ cup sugar"` →
/// `"¾ cup sugar"` (the fraction math reuses ``FractionRenderer`` from T-440).
///
/// **What it never merges (stays separate):** lines whose units differ
/// (`"2 cups onion"` + `"1 lb onion"`), lines with no parseable leading
/// quantity (`"Salt and pepper to taste"`), and lines whose names differ
/// (`"yellow onion"` vs `"red onion"`). The aggregator does NOT do cross-unit
/// density-aware normalization — that was CL-70's struck option (c).
///
/// **Ordering:** results are grouped by aisle in ``IngredientAisleClassifier``
/// `Aisle.allCases` declaration order (the AC-39.4 store-walk order for the
/// logic-core case set), and within an aisle the first-seen input order is
/// preserved (stable).
public enum IngredientAggregator {

    /// One combined shopping-list line.
    public struct AggregatedItem: Equatable, Sendable, Identifiable {

        /// Stable identity derived from the merge key (unit + name) or, for
        /// unmerged/unparseable lines, the verbatim text. Lets a UI diff the
        /// list without an extra index.
        public let id: String

        /// The store aisle this item belongs to (from the classifier).
        public let aisle: IngredientAisleClassifier.Aisle

        /// The display line: `"<rendered quantity> <unit> <name>"` for merged
        /// items (e.g. `"3 cups flour"`), or the verbatim original text for
        /// items that had no parseable quantity (e.g. `"Salt to taste"`).
        public let displayText: String

        /// The parsed ingredient name (whitespace-collapsed, original case of
        /// the first occurrence). `nil` for unparseable lines that fell back
        /// to verbatim ``displayText``.
        public let name: String?

        /// The normalized unit (singular, lowercased — `"cup"`), or `nil` when
        /// no unit was parsed.
        public let unit: String?

        /// The summed numeric quantity, or `nil` when no quantity was parsed.
        public let quantity: Double?

        /// How many input lines folded into this item (`1` when nothing
        /// merged). Lets a UI surface "from N recipes" if it wants to.
        public let sourceCount: Int

        public init(
            id: String,
            aisle: IngredientAisleClassifier.Aisle,
            displayText: String,
            name: String?,
            unit: String?,
            quantity: Double?,
            sourceCount: Int
        ) {
            self.id = id
            self.aisle = aisle
            self.displayText = displayText
            self.name = name
            self.unit = unit
            self.quantity = quantity
            self.sourceCount = sourceCount
        }
    }

    /// Aggregate a flat ingredient list into combined, aisle-tagged items.
    ///
    /// - Parameter ingredients: Raw ingredient lines (the ``RecipeIngredient``
    ///   `text` is all that's read; the `id` is ignored — merging is by
    ///   parsed unit + name, not by source identity).
    /// - Returns: One ``AggregatedItem`` per distinct mergeable group, plus one
    ///   per unparseable line, ordered by aisle then first-seen.
    public static func aggregate(_ ingredients: [RecipeIngredient]) -> [AggregatedItem] {
        var order: [String] = []
        var groups: [String: MutableGroup] = [:]

        for (index, ingredient) in ingredients.enumerated() {
            let parsed = IngredientLineParser.parse(ingredient.text)
            let key = mergeKey(for: parsed, fallback: ingredient.text)
            if var existing = groups[key] {
                existing.add(parsed)
                groups[key] = existing
            } else {
                order.append(key)
                groups[key] = MutableGroup(parsed: parsed, firstSeen: index)
            }
        }

        let items = order.compactMap { groups[$0]?.finalize() }
        // Stable group-by-aisle: `sorted(by:)` isn't guaranteed stable, so the
        // tiebreak is the first-seen index captured when the group was created.
        return items.sorted { lhs, rhs in
            if lhs.aisleRank != rhs.aisleRank { return lhs.aisleRank < rhs.aisleRank }
            return lhs.firstSeen < rhs.firstSeen
        }
        .map(\.item)
    }

    // MARK: - Grouping internals

    /// An aggregated item plus the sort keys used to order it. The sort keys
    /// are stripped before the public result is returned.
    private struct RankedItem {
        let item: AggregatedItem
        let aisleRank: Int
        let firstSeen: Int
    }

    /// Accumulator for one merge group as lines fold in.
    private struct MutableGroup {
        let parsed: ParsedIngredientLine
        let firstSeen: Int
        var summedQuantity: Double?
        var count: Int

        init(parsed: ParsedIngredientLine, firstSeen: Int) {
            self.parsed = parsed
            self.firstSeen = firstSeen
            self.summedQuantity = parsed.quantity
            self.count = 1
        }

        mutating func add(_ next: ParsedIngredientLine) {
            count += 1
            // Sum only when BOTH lines carry a quantity. `mergeKey` already
            // keeps unparseable lines unique, so in practice this branch only
            // runs for genuinely mergeable (quantity + unit + name) groups.
            if let running = summedQuantity, let addend = next.quantity {
                summedQuantity = running + addend
            }
        }

        func finalize() -> RankedItem {
            let aisle = IngredientAisleClassifier.classify(parsed.matchSource)
            let item = AggregatedItem(
                id: identity,
                aisle: aisle,
                displayText: renderedDisplay(quantity: summedQuantity),
                name: parsed.name,
                unit: parsed.unit,
                quantity: summedQuantity,
                sourceCount: count
            )
            return RankedItem(
                item: item,
                aisleRank: IngredientAggregator.aisleRank(aisle),
                firstSeen: firstSeen
            )
        }

        /// Mergeable groups key on unit + name; unparseable ones key on the
        /// verbatim text plus the first-seen index (so two identical
        /// unparseable lines still get distinct, stable ids).
        private var identity: String {
            guard let unit = parsed.unit, let name = parsed.name, parsed.quantity != nil else {
                return "raw:\(parsed.originalText)#\(firstSeen)"
            }
            return "merge:\(unit)|\(name)"
        }

        /// `"<qty> <unit> <name>"` for parsed lines; verbatim text otherwise.
        private func renderedDisplay(quantity: Double?) -> String {
            guard let quantity, let name = parsed.name, parsed.quantity != nil else {
                return parsed.originalText
            }
            let qty = FractionRenderer.renderQuantity(quantity)
            if let unit = parsed.unit, !unit.isEmpty {
                let unitText = IngredientAggregator.pluralizedUnit(unit, for: quantity)
                return "\(qty) \(unitText) \(name)"
            }
            return "\(qty) \(name)"
        }
    }

    /// Pluralize the canonical singular unit for display: `1 → "cup"`,
    /// `3 → "cups"`. Units that don't pluralize with a bare `s` (the
    /// abbreviations) are returned unchanged.
    private static func pluralizedUnit(_ singular: String, for quantity: Double) -> String {
        guard quantity > 1 else { return singular }
        guard pluralizableUnits.contains(singular) else { return singular }
        return singular + "s"
    }

    /// Long-form units that read naturally with a trailing `s`. Abbreviations
    /// (`tsp`, `oz`, `lb`) are intentionally excluded — `"3 tsp"` not
    /// `"3 tsps"`.
    private static let pluralizableUnits: Set<String> = [
        "cup", "tablespoon", "teaspoon", "pound", "ounce", "gram", "clove",
        "can", "package", "sprig", "stick", "slice", "pinch", "quart", "pint",
    ]

    /// The merge key: unit + name for parseable lines (so they cluster), or a
    /// per-line unique key for unparseable lines (so they never merge).
    private static func mergeKey(for parsed: ParsedIngredientLine, fallback: String) -> String {
        guard let unit = parsed.unit, let name = parsed.name, parsed.quantity != nil else {
            // No quantity/unit → keep this line distinct. Salt-to-taste lines
            // and bare counts ("2 eggs" has no *unit*) stay separate; a UUID
            // suffix guarantees uniqueness even for identical text.
            return "raw:\(fallback)#\(UUID().uuidString)"
        }
        return "merge:\(unit)|\(name)"
    }

    private static func aisleRank(_ aisle: IngredientAisleClassifier.Aisle) -> Int {
        IngredientAisleClassifier.Aisle.allCases.firstIndex(of: aisle) ?? .max
    }
}
