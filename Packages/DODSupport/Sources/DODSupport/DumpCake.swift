import Foundation

/// A dump cake the cook can pick for a coached cookout (DUT-190).
///
/// Dump cakes are all the **same method** (dump the fruit, dump the cake mix,
/// dot with butter, lid on, bake), so the app doesn't curate coaching per cake.
/// One generic ``GuidedCookout/dumpCake(_:)`` template covers the whole blog
/// collection; a `DumpCake` just carries which recipe the user chose so the flow
/// can link it + log it.
public struct DumpCake: Identifiable, Sendable, Equatable {

    /// WP post id (drives the journal log + must match the recipe detail).
    public let id: Int
    /// WP slug (the *cook* stage opens `base/<slug>/` in-app).
    public let slug: String
    /// Display title in the picker + the coached flow.
    public let title: String

    public init(id: Int, slug: String, title: String) {
        self.id = id
        self.slug = slug
        self.title = title
    }
}

extension DumpCake {

    /// Curated dump cakes from `dutchovendaddy.com` (DUT-190). A static list for
    /// v1 — a dynamic dump-cake category/tag fetch (so new cakes appear
    /// automatically) is the noted follow-up.
    public static let all: [DumpCake] = [
        DumpCake(id: 16370, slug: "lemon-blueberry-dump-cake", title: "Lemon Blueberry Dump Cake"),
        // DUT-284 fix: this carried id 22294 (the Dutch Oven Heat Coach's
        // `dutch-oven-temperature-chart` post, which is `GuidedCookout.campfire`'s
        // `recipeID`) instead of `peach-dump-cake`'s own WP post id (546). The
        // wrong id logged a cook here as recipeID 22294 to the cook journal (DUT-104)
        // — colliding with the campfire capstone's id, which falsely satisfied
        // `GuidedCookout.nextUncookedRung` and marked "Take It to the Campfire" as
        // already cooked the first time anyone made this dump cake at home, even
        // though they never took a dish outdoors. Confirmed against the live WP
        // REST API (`/wp-json/wp/v2/posts?slug=peach-dump-cake` → id 546;
        // `/wp-json/wp/v2/posts/22294` → `dutch-oven-temperature-chart`).
        DumpCake(id: 546, slug: "peach-dump-cake", title: "Peach Dump Cake"),
        DumpCake(id: 19904, slug: "dutch-oven-peach-cobbler", title: "Dutch Oven Peach Cobbler"),
        DumpCake(id: 23570, slug: "peach-blueberry-cobbler", title: "Peach Blueberry Cobbler"),
        DumpCake(
            id: 22467,
            slug: "skillet-strawberry-rhubarb-cobbler",
            title: "Strawberry Rhubarb Cobbler"
        ),
        DumpCake(id: 279, slug: "apple-pie-oatmeal-crisp", title: "Skillet Apple Crisp"),
    ]
}

extension GuidedCookout {

    /// A generic coached cookout for ANY dump cake (DUT-190). Dump cakes share
    /// one method, so this single parameterized template (fed the chosen
    /// ``DumpCake``'s slug / id / title) gives the user the full gather → fire →
    /// cook → celebrate flow, the live coal count, the bake timer, and the
    /// in-app recipe link for whichever cake they picked — without curating
    /// per-cake content. The coaching/gear/ingredients are generic (below);
    /// only the recipe link + title change per cake.
    public static func dumpCake(_ cake: DumpCake) -> GuidedCookout {
        GuidedCookout(
            recipeSlug: cake.slug,
            recipeID: cake.id,
            dishTitle: cake.title,
            whyThisDish: dumpCakeWhyThisDish,
            steps: dumpCakeSteps,
            celebrationMessage: dumpCakeCelebration,
            nextStepPrompt: dumpCakeNextStep,
            ovenTempF: 350,
            ovenDiameterInches: 12,
            bakeMinutes: 40,
            gear: dumpCakeGear,
            ingredients: dumpCakeIngredients
        )
    }

    // MARK: - Generic dump-cake content (de-em-dashed, Ned's voice)

    private static let dumpCakeWhyThisDish =
        "Dump cakes are the easiest hero move there is. You dump the fruit, dump the cake "
        + "mix right on top, dot it with butter, and put the lid on. No mixing, no stress, "
        + "and everyone thinks you're a genius when you scoop it out warm."

    private static let dumpCakeSteps: [Step] = [
        Step(
            id: "gather-gear",
            stage: .gather,
            title: "Round Up Your Gear and Ingredients",
            coaching:
                "Three simple things: your fruit, a box of cake mix, and a stick of butter. "
                + "That's the whole secret. Get it all out and you're halfway there."
        ),
        Step(
            id: "light-coals",
            stage: .fire,
            title: "Get Your Coals Going",
            coaching:
                "Coals on the bottom and the lid for a steady bake. I'll tell you exactly how "
                + "many and where, same as always. You've done this."
        ),
        Step(
            id: "dump-and-lid",
            stage: .cook,
            title: "Dump It, Dot It, Lid It",
            coaching:
                "Dump the fruit in, spread the dry cake mix evenly over the top, and slice the "
                + "butter across it. Do not stir. Lid on, and walk away. The Dutch oven does "
                + "the rest."
        ),
        Step(
            id: "scoop-it-warm",
            stage: .celebrate,
            title: "Lift the Lid",
            coaching:
                "Bubbling, golden, smells like a county fair. Scoop it warm, add ice cream if "
                + "you've got it, and watch everyone's faces. Snap a photo first."
        ),
    ]

    private static let dumpCakeCelebration =
        "You just made dessert in a Dutch oven, and it was almost impossible to mess up. This "
        + "is the move that makes you the hero at every cookout from here on."

    private static let dumpCakeNextStep =
        "Make it again with a different fruit and cake mix, then bring it to the campfire. "
        + "Warm cobbler outdoors is unbeatable."

    private static let dumpCakeGear = [
        "12-inch Dutch oven with a lid",
        "Lid lifter or a sturdy pair of pliers",
        "Charcoal briquettes + a chimney starter",
        "Heat-proof gloves",
        "A trivet or flat spot to set the oven on",
    ]

    private static let dumpCakeIngredients = [
        "1 to 2 cans pie filling, or 4 to 6 cups fresh or frozen fruit",
        "1 box cake mix (yellow or white works for almost anything)",
        "1 stick (½ cup) butter, sliced thin",
        "Optional: cinnamon, or a handful of chopped nuts",
        "Vanilla ice cream, to serve",
    ]
}
