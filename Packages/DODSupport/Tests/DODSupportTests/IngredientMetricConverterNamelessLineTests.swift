import Foundation
import Testing

@testable import DODSupport

/// DUT-913 — a bare "N unit" ingredient line with no trailing food name
/// ("2 cups", "1 pound") was left UNCONVERTED in metric mode. `parse(_:)`
/// returns all-nil for a nameless line (correct for the shopping-list
/// aggregator, which treats it as unmergeable verbatim), so the metric
/// converter discarded a quantity+unit it could have converted. It now falls
/// back to `parseQuantityAndUnit`, emitting the metric unit alone.
@Suite("IngredientMetricConverter nameless line (DUT-913)")
struct MetricConverterNamelessLineTests {

    @Test func bareQuantityUnitConvertsWithoutAName() {
        #expect(IngredientMetricConverter.metric("2 cups") == "480 ml")
        #expect(IngredientMetricConverter.metric("1 pound") == "450 g")
        #expect(IngredientMetricConverter.metric("8 ounces") == "220 g")
        #expect(IngredientMetricConverter.metric("3 tablespoons") == "45 ml")
    }

    @Test func namedLinesStillConvertWithTheName() {
        #expect(IngredientMetricConverter.metric("2 cups water") == "480 ml water")
        #expect(IngredientMetricConverter.metric("8 ounces cheese") == "220 g cheese")
    }

    @Test func nonConvertibleOrUnparseableLinesAreUnchanged() {
        // No convertible unit → unchanged.
        #expect(IngredientMetricConverter.metric("2 large eggs") == "2 large eggs")
        #expect(IngredientMetricConverter.metric("a pinch of salt") == "a pinch of salt")
        // Already metric / count units are still passed through.
        #expect(IngredientMetricConverter.metric("2 cloves") == "2 cloves")
        // No leading quantity at all.
        #expect(IngredientMetricConverter.metric("Salt and pepper") == "Salt and pepper")
    }

    @Test func parseQuantityAndUnitRecoversWhatParseDrops() {
        // The seam itself: bare qty+unit recovered where parse() returns all-nil.
        let bare = IngredientLineParser.parseQuantityAndUnit("2 cups")
        #expect(bare?.quantity == 2)
        #expect(bare?.unit == "cup")
        #expect(IngredientLineParser.parse("2 cups").quantity == nil)  // parse() unchanged
    }
}
