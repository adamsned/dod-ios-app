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
            id: 16370,
            slug: "lemon-blueberry-dump-cake",
            title: "Lemon Blueberry Dump Cake"
        )
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

    @Test("Peach Dump Cake (DUT-284)") func peachDumpCakeIsAvailable() {
        let peachDumpCake = DumpCake(
            id: 546,
            slug: "peach-dump-cake",
            title: "Peach Dump Cake"
        )
        #expect(DumpCake.all.contains(peachDumpCake))
        #expect(peachDumpCake.id == 546)
        #expect(peachDumpCake.slug == "peach-dump-cake")
        #expect(peachDumpCake.title == "Peach Dump Cake")
    }

    /// Regression test for a real data bug: `peach-dump-cake` was wired to WP
    /// post id 22294 — which is actually `dutch-oven-temperature-chart`, the
    /// same post `GuidedCookout.campfire.recipeID` uses as the outdoor-guide
    /// reference. Because `GuidedCookout.dumpCake(_:)` logs `cake.id` as the
    /// cook-journal `recipeID` (``FirstCookoutView+Logging``), an id collision
    /// between ANY dump cake and ANY path rung would let cooking that dump
    /// cake falsely satisfy `GuidedCookout.nextUncookedRung` for the colliding
    /// rung — e.g. marking "Take It to the Campfire" as already done. This
    /// checks every dump cake against every rung (not just index 0, which is
    /// all ``dumpCakesAreAFlexibleBranchNotAFixedRung`` covers) so a future
    /// curated dump cake can't reintroduce the same class of bug.
    @Test("No dump cake shares a WP post id with any path rung (DUT-284 regression)")
    func noDumpCakeCollidesWithAPathRung() {
        for cake in DumpCake.all {
            for rung in GuidedCookout.path {
                #expect(
                    cake.id != rung.recipeID,
                    """
                    Collision: DumpCake "\(cake.title)" (id \(cake.id)) shares its WP \
                    post id with path rung "\(rung.dishTitle)" (recipeID \(rung.recipeID)).
                    """
                )
            }
        }
    }
}
