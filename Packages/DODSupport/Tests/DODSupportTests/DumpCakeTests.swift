import Testing

@testable import DODSupport

/// L1 coverage for the dump-cake option (DUT-190) — the curated list + the
/// generic, parameterized coached template that covers any blog dump cake.
@Suite("DumpCake (DUT-190)")
struct DumpCakeTests {

    @Test func curatedListIsNonEmptyWithRealRecipes() {
        #expect(DumpCake.all.isEmpty == false)
        for cake in DumpCake.all {
            #expect(cake.id > 0)
            #expect(cake.slug.isEmpty == false)
            #expect(cake.title.isEmpty == false)
        }
    }

    @Test func templateUsesTheChosenRecipe() {
        let cake = DumpCake(
            id: 16370, slug: "lemon-blueberry-dump-cake", title: "Lemon Blueberry Dump Cake")
        let cookout = GuidedCookout.dumpCake(cake)
        #expect(cookout.recipeID == 16370)
        #expect(cookout.recipeSlug == "lemon-blueberry-dump-cake")
        #expect(cookout.dishTitle == "Lemon Blueberry Dump Cake")
        // Full coached flow with generic dump-cake content.
        #expect(cookout.steps.count == 4)
        #expect(cookout.gear.isEmpty == false)
        #expect(cookout.ingredients.isEmpty == false)
    }

    @Test func dumpCakesAreAFlexibleBranchNotAFixedRung() {
        let cookout = GuidedCookout.dumpCake(DumpCake.all[0])
        #expect(cookout.isFirstRung == false)
        #expect(GuidedCookout.path.contains { $0.recipeID == cookout.recipeID } == false)
    }
}
