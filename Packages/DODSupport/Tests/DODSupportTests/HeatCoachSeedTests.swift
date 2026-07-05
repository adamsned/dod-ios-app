import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``HeatCoachSeed`` (DUT-584) — the recipe→coach prefill
/// contract. Pins the four-way ``CharcoalRecipeConverter/CookTask`` →
/// two-way ``CookingStyle`` mapping the coach opens with, so a recipe's derived
/// task always lands the cook on the right lid/bottom split.
@Suite("HeatCoachSeed") struct HeatCoachSeedTests {

    // MARK: - Task → style mapping (only .bake is lid-heavy)

    @Test func bakeTask_mapsToBakingStyle() {
        #expect(HeatCoachSeed.style(forRecipeTask: .bake) == .baking)
    }

    @Test func roastSimmerFryTasks_mapToEvenStyle() {
        #expect(HeatCoachSeed.style(forRecipeTask: .roast) == .even)
        #expect(HeatCoachSeed.style(forRecipeTask: .simmer) == .even)
        #expect(HeatCoachSeed.style(forRecipeTask: .fry) == .even)
    }

    @Test func everyTaskMapsToAStyle() {
        // Exhaustive over the four tasks so a new CookTask can't silently
        // fall through the mapping.
        for task in CharcoalRecipeConverter.CookTask.allCases {
            let style = HeatCoachSeed.style(forRecipeTask: task)
            #expect(style == .even || style == .baking)
        }
    }

    // MARK: - Recipe-task convenience init threads the values through

    @Test func recipeTaskInit_carriesDiameterStyleAndTemperature() {
        let seed = HeatCoachSeed(
            fromRecipeTask: .bake,
            ovenDiameterInches: 12,
            targetTemperatureF: 350
        )
        #expect(seed.ovenDiameterInches == 12)
        #expect(seed.style == .baking)
        #expect(seed.targetTemperatureF == 350)
    }

    @Test func recipeTaskInit_roast_isEvenStyle() {
        let seed = HeatCoachSeed(
            fromRecipeTask: .roast,
            ovenDiameterInches: 12,
            targetTemperatureF: 375
        )
        #expect(seed.style == .even)
        #expect(seed.targetTemperatureF == 375)
    }

    @Test func plainInit_allowsNilTemperature() {
        let seed = HeatCoachSeed(ovenDiameterInches: 14, style: .even)
        #expect(seed.ovenDiameterInches == 14)
        #expect(seed.style == .even)
        #expect(seed.targetTemperatureF == nil)
    }
}
