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
            + "more forgiving than the lasagna. You braise it with carrots and potatoes in "
            + "Italian dressing until it falls apart, then turn the rich liquid into gravy. "
            + "Saucy, hearty, and the kind of meal people ask you to make again.",
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
                title: "Layer it, braise it, make the gravy",
                coaching:
                    "Nestle the chicken in with the carrots and potatoes, pour the dressing, "
                    + "ginger ale, and soy over, set the lid, and walk away. At the end you'll "
                    + "whisk the cooking liquid with cream into a rich gravy. I'll keep the "
                    + "timer with you."
            ),
            Step(
                id: "lift-the-lid",
                stage: .celebrate,
                title: "Lift the lid",
                coaching:
                    "Fall-apart chicken in a rich gravy, with the potatoes and carrots right "
                    + "there. Plate it up, snap a photo, and dig in. You're two for two now."
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
            "3 lbs chicken breast, cut into tenders",
            "16 oz Italian salad dressing",
            "2 lbs baby carrots",
            "1½ lbs Yukon gold potatoes, cubed",
            "1½ lbs red potatoes, cubed",
            "12 oz ginger ale",
            "5 oz soy sauce",
            "2 cups heavy cream",
            "½ cup cornstarch",
            "2 tbsp parsley, chopped (optional)",
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
