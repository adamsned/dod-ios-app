import Foundation

/// The hero's **path** (DUT-183) — the ordered ladder of curated cookouts that
/// turns one guaranteed win into a journey. The north star isn't a recipe
/// database; it's a coached climb, one rung at a time: the lasagna, then the
/// Italian chicken in gravy, and on toward the campfire.
///
/// Rung content here is starter copy in Ned's voice (refined later, like the
/// first cookout + the DO-101 guides). Copy avoids em-dashes per Ned's
/// preference.
extension GuidedCookout {

    /// Rung 2 — Ned's **Italian chicken in gravy**: even more forgiving than the
    /// lasagna (a dump-and-braise), rich and saucy, the kind of meal people ask
    /// you to make again. The natural next confidence-builder after a first win.
    public static let italianChicken = GuidedCookout(
        recipeSlug: "dutch-oven-italian-chicken-in-gravy",
        recipeID: 683,
        dishTitle: "Italian Chicken in Gravy",
        whyThisDish:
            "You've got one win under your belt, so here's your next. This chicken is even "
            + "more forgiving than the lasagna. You layer it, pour the gravy over, and let "
            + "it braise low and slow until it falls apart. Rich, saucy, and the kind of "
            + "meal people ask you to make again.",
        steps: [
            Step(
                id: "gather-gear",
                stage: .gather,
                title: "Round up your gear and ingredients",
                coaching:
                    "Same gear as last time. This one is barely more than a dump and "
                    + "braise, so getting it all out first makes it feel effortless."
            ),
            Step(
                id: "light-coals",
                stage: .fire,
                title: "Get your coals going",
                coaching:
                    "You did this for the lasagna and you'll do it again here. A low, "
                    + "steady heat is all a braise wants. I'll give you the coal count for "
                    + "the lid and the bottom."
            ),
            Step(
                id: "layer-and-braise",
                stage: .cook,
                title: "Layer it, pour the gravy, let it braise",
                coaching:
                    "Nestle the chicken in, pour the gravy right over the top, set the lid, "
                    + "and walk away. The longer it goes, the more tender it gets. I'll "
                    + "keep the timer with you."
            ),
            Step(
                id: "lift-the-lid",
                stage: .celebrate,
                title: "Lift the lid",
                coaching:
                    "Fall-apart chicken in a rich gravy. Spoon it over rice or bread, snap "
                    + "a photo, and dig in. You're two for two now."
            ),
        ],
        celebrationMessage:
            "Two cookouts down. That wasn't luck, that's a skill you have now. The lasagna "
            + "and this chicken are the two I lean on most, and you can cook both.",
        nextStepPrompt:
            "Cook this one again for the people you love. When you're ready, the real "
            + "magic is taking it outdoors to the campfire.",
        ovenTempF: 350,
        ovenDiameterInches: 12,
        bakeMinutes: 50,
        gear: [
            "12-inch Dutch oven with a lid",
            "Lid lifter or a sturdy pair of pliers",
            "Charcoal briquettes + a chimney starter",
            "Heat-proof gloves",
            "A trivet or flat spot to set the oven on",
        ],
        ingredients: [
            "6 bone-in chicken thighs (or a cut-up whole chicken)",
            "1 bottle (16 oz) Italian dressing",
            "2 cans (10.5 oz) cream of chicken soup",
            "8 oz cream cheese, softened",
            "1 tsp Italian seasoning",
            "Salt + pepper",
            "Cooked rice or crusty bread, to serve",
        ]
    )

    /// The ordered ladder of curated cookouts. One guaranteed win at a time;
    /// more rungs slot in here as Ned curates them.
    public static let path: [GuidedCookout] = [firstCookout, italianChicken]

    /// The next rung the cook hasn't done yet, given the recipe ids they've
    /// logged (the DUT-104 cook journal). Returns the first un-cooked rung in
    /// ``path``, or nil once every rung is cooked (a path graduate).
    public static func nextUncookedRung(cookedRecipeIDs: Set<Int>) -> GuidedCookout? {
        path.first { !cookedRecipeIDs.contains($0.recipeID) }
    }

    /// True when this cookout is the first rung of the path — drives the
    /// "Your First Cookout" vs "Your Next Cookout" hero framing.
    public var isFirstRung: Bool {
        recipeID == Self.path.first?.recipeID
    }
}
