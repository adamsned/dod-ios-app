import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 — pins ``NutritionScaler``'s contract: nutrition facts scale by the
/// same ratio the ingredient list already applies (``FractionRenderer``'s
/// equivalent for quantities), with units preserved and non-numeric /
/// absent values left untouched.
///
/// Spec trace: DUT-895 (iOS parity twin of DUT-892 / Android).
@Suite("NutritionScaler (DUT-895)")
struct NutritionScalerTests {

    // MARK: - scale(_:by:) — single value

    @Test func ratioOneLeavesValueUnchanged() {
        #expect(NutritionScaler.scale("12 g", by: 1.0) == "12 g")
    }

    @Test func ratioTwoDoublesTheLeadingNumber() {
        #expect(NutritionScaler.scale("12 g", by: 2.0) == "24 g")
        #expect(NutritionScaler.scale("240 kcal", by: 2.0) == "480 kcal")
    }

    @Test func ratioHalfHalvesTheLeadingNumber() {
        #expect(NutritionScaler.scale("12 g", by: 0.5) == "6 g")
        #expect(NutritionScaler.scale("240 kcal", by: 0.5) == "120 kcal")
    }

    @Test func nonNumericValueIsUntouched() {
        #expect(NutritionScaler.scale("N/A", by: 2.0) == "N/A")
        #expect(NutritionScaler.scale("", by: 2.0)?.isEmpty == true)
    }

    @Test func nilValueStaysNil() {
        #expect(NutritionScaler.scale(nil, by: 2.0) == nil)
    }

    @Test func decimalValueRoundsToOneDecimalPlaceAndDropsTrailingZero() {
        // 7 g halved is a genuine .5 — kept.
        #expect(NutritionScaler.scale("7 g", by: 0.5) == "3.5 g")
        // 10.5 g doubled lands back on a whole number — trailing .0 dropped.
        #expect(NutritionScaler.scale("10.5 g", by: 2.0) == "21 g")
    }

    @Test func gluedUnitWithNoSpaceStaysGlued() {
        #expect(NutritionScaler.scale("10.5g", by: 2.0) == "21g")
    }

    @Test func nonPositiveOrNonFiniteRatioIsANoOp() {
        #expect(NutritionScaler.scale("12 g", by: 0) == "12 g")
        #expect(NutritionScaler.scale("12 g", by: -2.0) == "12 g")
        #expect(NutritionScaler.scale("12 g", by: .infinity) == "12 g")
        #expect(NutritionScaler.scale("12 g", by: .nan) == "12 g")
    }

    // MARK: - scaledNutrition(_:by:) — whole RecipeNutrition

    @Test func scaledNutritionNilInputReturnsNil() {
        #expect(NutritionScaler.scaledNutrition(nil, by: 2.0) == nil)
    }

    @Test func scaledNutritionAtRatioOneIsUnchanged() {
        let source = RecipeNutrition(
            calories: "240 kcal",
            servingSize: "1 cup",
            proteinGrams: "12 g",
            carbsGrams: "30 g",
            fatGrams: "8 g"
        )
        #expect(NutritionScaler.scaledNutrition(source, by: 1.0) == source)
    }

    @Test func scaledNutritionAtRatioTwoDoublesEveryFieldExceptServingSize() {
        let source = RecipeNutrition(
            calories: "240 kcal",
            servingSize: "1 cup",
            proteinGrams: "12 g",
            carbsGrams: "30 g",
            fatGrams: "8 g"
        )
        let scaled = NutritionScaler.scaledNutrition(source, by: 2.0)
        #expect(
            scaled
                == RecipeNutrition(
                    calories: "480 kcal",
                    servingSize: "1 cup",
                    proteinGrams: "24 g",
                    carbsGrams: "60 g",
                    fatGrams: "16 g"
                )
        )
    }

    @Test func scaledNutritionAtRatioHalfHalvesEveryFieldExceptServingSize() {
        let source = RecipeNutrition(
            calories: "240 kcal",
            servingSize: "1 cup",
            proteinGrams: "12 g",
            carbsGrams: "30 g",
            fatGrams: "8 g"
        )
        let scaled = NutritionScaler.scaledNutrition(source, by: 0.5)
        #expect(
            scaled
                == RecipeNutrition(
                    calories: "120 kcal",
                    servingSize: "1 cup",
                    proteinGrams: "6 g",
                    carbsGrams: "15 g",
                    fatGrams: "4 g"
                )
        )
    }

    @Test func scaledNutritionWithNonNumericFieldLeavesItUntouched() {
        let source = RecipeNutrition(calories: "N/A", servingSize: "1 cup", proteinGrams: nil)
        let scaled = NutritionScaler.scaledNutrition(source, by: 2.0)
        #expect(scaled?.calories == "N/A")
        #expect(scaled?.proteinGrams == nil)
        #expect(scaled?.servingSize == "1 cup")
    }
}
