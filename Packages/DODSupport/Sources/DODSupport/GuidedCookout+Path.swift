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
                title: "Round Up Your Gear and Ingredients",
                coaching:
                    "Same gear as last time. This one is barely more than a dump and "
                    + "braise, so getting it all out first makes it feel effortless."
            ),
            Step(
                id: "light-coals",
                stage: .fire,
                title: "Get Your Coals Going",
                coaching:
                    "You did this for the lasagna and you'll do it again here. A low, "
                    + "steady heat is all a braise wants. I'll give you the coal count for "
                    + "the lid and the bottom."
            ),
            Step(
                id: "layer-and-braise",
                stage: .cook,
                title: "Layer It, Braise It, Make the Gravy",
                coaching:
                    "Nestle the chicken in with the carrots and potatoes, pour the dressing, "
                    + "ginger ale, and soy over, set the lid, and walk away. At the end you'll "
                    + "whisk the cooking liquid with cream into a rich gravy. I'll keep the "
                    + "timer with you."
            ),
            Step(
                id: "lift-the-lid",
                stage: .celebrate,
                title: "Lift the Lid",
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

    /// The capstone (DUT-192) — **Take It to the Campfire**. The path's peak: the
    /// hero who built confidence at home now cooks outdoors, over a real fire,
    /// for the people they love. Dish-agnostic (bring a dish you've already
    /// nailed); the coaching is the outdoor layer plus the word-of-mouth moment.
    /// Links the heat/coals-by-feel guide as the outdoor reference.
    public static let campfire = GuidedCookout(
        recipeSlug: "dutch-oven-temperature-chart",
        recipeID: 22294,
        dishTitle: "Take It to the Campfire",
        whyThisDish:
            "This is the one you've been building toward. Take a dish you've already nailed "
            + "at home and cook it outdoors, over a real fire, for the people you love. The "
            + "cooking is the same. What changes is the moment: everyone gathered around, "
            + "watching you lift the lid. That's when you become the person they ask to cook.",
        steps: [
            Step(
                id: "plan-and-pack",
                stage: .gather,
                title: "Pack the Dish You've Mastered",
                coaching:
                    "Pick the cook you already know, the lasagna or the chicken. Pack your "
                    + "Dutch oven, coals, a chimney, gloves, and a flat rock or trivet. You "
                    + "know this one. You're just bringing it outside."
            ),
            Step(
                id: "outdoor-fire",
                stage: .fire,
                title: "Build Your Fire, Beat the Wind",
                coaching:
                    "Outdoors, wind and cold steal heat. Light your chimney and add three or "
                    + "four coals to your usual count, then pick a spot out of the wind. I'll "
                    + "give you the adjusted numbers."
            ),
            Step(
                id: "cook-and-be-present",
                stage: .cook,
                title: "Set It, Then Be With Your People",
                coaching:
                    "Level ground, coals top and bottom, lid on. Here's the best part: you "
                    + "cook while you're with everyone, not stuck at a stove. Give it a "
                    + "quarter turn now and then. Otherwise, sit by the fire."
            ),
            Step(
                id: "the-moment",
                stage: .celebrate,
                title: "Lift the Lid in Front of Everyone",
                coaching:
                    "This is the moment they remember. Serve it around the fire, snap the "
                    + "photo, and when someone asks how you did it, tell them. Then send them "
                    + "the app."
            ),
        ],
        celebrationMessage:
            "You just cooked for your people, outdoors, over fire. That is the whole thing. "
            + "You're not learning anymore, you're the one they count on. This is what a "
            + "Dutch Oven Daddy is.",
        nextStepPrompt:
            "Do it again, and bring someone new into it. The best cooks make more cooks. "
            + "That's how this spreads.",
        ovenTempF: 375,
        ovenDiameterInches: 12,
        bakeMinutes: 45,
        gear: [
            "12-inch Dutch oven with a lid",
            "Lid lifter or a sturdy pair of pliers",
            "Charcoal + a chimney starter (pack extra for the wind)",
            "Heat-proof gloves",
            "A flat rock, trivet, or fire ring",
            "Something to block the wind",
        ],
        ingredients: [
            "Everything for the dish you've already nailed at home",
            "A few extra coals for the wind and cold",
            "The people you want to feed, gathered around the fire",
        ]
    )

    /// The ordered ladder of curated cookouts: the home rungs, then the campfire
    /// capstone. One guaranteed win at a time, building toward cooking outdoors
    /// for the people you love. More rungs slot in here as Ned curates them.
    public static let path: [GuidedCookout] = [firstCookout, italianChicken, campfire]

    /// The next rung the cook hasn't done yet, given the recipe ids they've
    /// logged (the DUT-104 cook journal). Returns the first rung in ``path``
    /// whose recipeID is NOT in `cookedRecipeIDs`, or nil once every rung is
    /// cooked (a path graduate).
    ///
    /// DUT-628: this honors `cookedRecipeIDs` for EVERY rung, not just an
    /// in-order high-water mark. So a cook who completed a later rung out of
    /// order (e.g. rung 2 before rung 1) is still recommended the earliest rung
    /// they genuinely haven't cooked (rung 1) — the hero never points at a rung
    /// already in the journal.
    public static func nextUncookedRung(cookedRecipeIDs: Set<Int>) -> GuidedCookout? {
        path.first { !cookedRecipeIDs.contains($0.recipeID) }
    }

    /// True when this cookout is the first rung of the path — drives the
    /// "Your First Cookout" vs "Your Next Cookout" hero framing.
    public var isFirstRung: Bool {
        recipeID == Self.path.first?.recipeID
    }

    /// True when this cookout is the campfire capstone (the outdoor peak) —
    /// drives the special "Take It to the Campfire" hero framing.
    public var isCampfire: Bool {
        recipeID == Self.campfire.recipeID
    }

    /// DUT-207: the intro-screen eyebrow. `FirstCookoutView` is reused for every
    /// rung, so it must NOT always read "Your First Cookout".
    public var introEyebrow: String {
        if isCampfire { return "You're Ready" }
        return isFirstRung ? "Your First Cookout" : "Your Next Cookout"
    }
}
