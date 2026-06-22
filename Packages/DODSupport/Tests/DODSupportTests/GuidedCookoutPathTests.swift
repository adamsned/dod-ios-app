import Testing

@testable import DODSupport

/// L1 coverage for the hero's PATH (DUT-183) — the ordered ladder of cookouts
/// and the next-uncooked-rung logic that drives the progress-aware Feed hero.
@Suite("GuidedCookout path (DUT-183)")
struct GuidedCookoutPathTests {

    @Test func pathIsHomeRungsThenCampfire() {
        #expect(GuidedCookout.path.count == 3)
        #expect(GuidedCookout.path[0].recipeID == GuidedCookout.firstCookout.recipeID)
        #expect(GuidedCookout.path[1].recipeID == GuidedCookout.italianChicken.recipeID)
        #expect(GuidedCookout.path[2].recipeID == GuidedCookout.campfire.recipeID)
    }

    @Test func italianChickenIsRung2WithRealRecipe() {
        let chicken = GuidedCookout.italianChicken
        #expect(chicken.recipeSlug == "dutch-oven-italian-chicken-in-gravy")
        #expect(chicken.recipeID == 683)
        #expect(chicken.dishTitle == "Italian Chicken in Gravy")
        #expect(chicken.gear.isEmpty == false)
        #expect(chicken.ingredients.isEmpty == false)
        // gather / fire / cook / celebrate.
        #expect(chicken.steps.count == 4)
    }

    @Test func nextUncookedRungWalksTheLadder() {
        // Nothing cooked yet -> rung 1 (the lasagna).
        #expect(
            GuidedCookout.nextUncookedRung(cookedRecipeIDs: [])?.recipeID
                == GuidedCookout.firstCookout.recipeID
        )
        // Lasagna cooked -> rung 2 (the chicken).
        let afterLasagna = GuidedCookout.nextUncookedRung(
            cookedRecipeIDs: [GuidedCookout.firstCookout.recipeID]
        )
        #expect(afterLasagna?.recipeID == GuidedCookout.italianChicken.recipeID)
        // Both home rungs cooked -> the campfire capstone.
        let homeRungs: Set<Int> = [
            GuidedCookout.firstCookout.recipeID, GuidedCookout.italianChicken.recipeID,
        ]
        #expect(
            GuidedCookout.nextUncookedRung(cookedRecipeIDs: homeRungs)?.recipeID
                == GuidedCookout.campfire.recipeID
        )
        // Every rung incl. the campfire -> nil (a true path graduate).
        let allCooked = homeRungs.union([GuidedCookout.campfire.recipeID])
        #expect(GuidedCookout.nextUncookedRung(cookedRecipeIDs: allCooked) == nil)
    }

    @Test func isFirstRungOnlyForRungOne() {
        #expect(GuidedCookout.firstCookout.isFirstRung == true)
        #expect(GuidedCookout.italianChicken.isFirstRung == false)
        #expect(GuidedCookout.campfire.isFirstRung == false)
    }

    @Test func campfireIsTheOutdoorCapstone() {
        let campfire = GuidedCookout.campfire
        #expect(campfire.isCampfire == true)
        #expect(GuidedCookout.firstCookout.isCampfire == false)
        #expect(campfire.recipeID == 22294)
        #expect(campfire.dishTitle == "Take It to the Campfire")
        #expect(campfire.steps.count == 4)
        #expect(campfire.gear.isEmpty == false)
        #expect(campfire.ingredients.isEmpty == false)
    }

    /// DUT-193 — guard against the gather checklist drifting back to fabricated
    /// ingredients: pin a signature ingredient from each real published recipe
    /// and assert the old made-up values are gone.
    @Test func rungIngredientsMatchTheRealRecipes() {
        let lasagna = GuidedCookout.firstCookout.ingredients.joined(separator: " | ")
        #expect(lasagna.contains("hot water"))  // the real Dutch-oven trick
        #expect(lasagna.contains("spaghetti sauce"))
        #expect(!lasagna.contains("no-boil"))  // the old fabricated value

        let chicken = GuidedCookout.italianChicken.ingredients.joined(separator: " | ")
        #expect(chicken.contains("ginger ale"))  // signature of the real recipe
        #expect(chicken.contains("Italian salad dressing"))
        #expect(!chicken.contains("cream of chicken"))  // the old fabricated value
    }
}
