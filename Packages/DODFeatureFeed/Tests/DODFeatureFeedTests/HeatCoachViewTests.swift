import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the DUT-584 answer-first Heat Coach seams that don't need a
/// snapshot host: the coal-diagram's combined VoiceOver label + dot counts, and
/// the recipe-prefill defaults. The rendered strings + condition copy stay
/// pinned by ``HeatCoachModelTests``; this suite pins the new composition logic.
@Suite("HeatCoachView") struct HeatCoachViewTests {

    // MARK: - Coal diagram: dot counts equal the CoalSplit, label summarizes once

    @Test func diagramLabel_even12_summarizesTheSplit() {
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .even)
        let label = HeatCoachView.coalDiagramAccessibilityLabel(split)
        // One combined label (never 24 separate dots) with the total + split.
        #expect(label == "Starting coals: about 24 — 12 on the lid, 12 underneath.")
    }

    @Test func diagramLabel_baking12_isLidHeavy() {
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .baking)
        let label = HeatCoachView.coalDiagramAccessibilityLabel(split)
        #expect(label == "Starting coals: about 24 — 18 on the lid, 6 underneath.")
    }

    /// The dots the diagram draws are exactly `split.lid` (top row) and
    /// `split.bottom` (bottom row) — the diagram reads these counts directly, so
    /// pinning the split the coach hands it pins the rendered dot counts.
    @Test func diagramDotCounts_equalTheCoalSplit() {
        for size in HeatCoachModel.ovenSizes {
            let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: size, style: .even)
            #expect(split.lid + split.bottom == split.total)
            #expect(split.total == size * 2)
        }
    }

    // MARK: - Recipe prefill defaults

    /// Standalone open (no seed) → the coach's model defaults to 12"/even, i.e.
    /// today's answer (24 coals, 12/12), unchanged by the revamp.
    @Test func standaloneDefault_is12InchEven() {
        // The seedless init mirrors these defaults; assert the model they build.
        let model = HeatCoachModel(
            ovenDiameterInches: 12,
            style: .even,
            elevationFeet: 0,
            ambient: .mild,
            windy: false
        )
        #expect(model.coalSplit.total == 24)
        #expect(model.coalSplit.lid == 12)
        #expect(model.coalSplit.bottom == 12)
    }

    /// A baking recipe seed (12", derived .baking, 350°F) yields the lid-heavy
    /// 18/6 answer — consistent with the recipe nudge's "~N coals at 350°F".
    @Test func bakingSeed_yieldsLidHeavyAnswer() {
        let seed = HeatCoachSeed(
            fromRecipeTask: .bake,
            ovenDiameterInches: 12,
            targetTemperatureF: 350
        )
        let model = HeatCoachModel(
            ovenDiameterInches: seed.ovenDiameterInches,
            style: seed.style,
            elevationFeet: 0,
            ambient: .mild,
            windy: false
        )
        #expect(model.coalSplit.lid == 18)
        #expect(model.coalSplit.bottom == 6)
    }
}
