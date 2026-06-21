import Foundation

/// The content spine of the "Your First Cookout" guided experience (US-53 /
/// DUT-183) — the keystone that turns a nervous beginner into a cast-iron hero.
///
/// This is a pure value model: the curated gateway dish, Ned's reassuring
/// coaching at each stage, and the celebration that captures the *"holy cow, I
/// did that"* moment. The UI flow (a later slice) renders these stages; keeping
/// the content as pure, testable data means the script can be tuned + validated
/// without a view host, and the same model can drive onboarding, a widget, or a
/// share card. The recipe steps/timer/coals come from the existing engines
/// (CookTimerEngine, CharcoalRecipeConverter, the recipe card) — this model is
/// the *spine* that orders them into one coached path.
public struct GuidedCookout: Sendable, Equatable {

    /// The four beats of a first cookout, in order.
    public enum Stage: String, Sendable, Equatable, CaseIterable {
        /// "Here's what you need" — gather gear + ingredients.
        case gather
        /// "Manage the fire" — light + place the coals (the scary part).
        case fire
        /// "Cook, coached" — layer, lid, and let the Dutch oven work.
        case cook
        /// "You did it" — lift the lid, capture the win.
        case celebrate
    }

    /// One coached step: the stage it belongs to, a short title, and Ned's
    /// reassuring coaching copy for that beat.
    public struct Step: Sendable, Equatable, Identifiable {
        public let id: String
        public let stage: Stage
        public let title: String
        public let coaching: String

        public init(id: String, stage: Stage, title: String, coaching: String) {
            self.id = id
            self.stage = stage
            self.title = title
            self.coaching = coaching
        }
    }

    /// WP recipe slug of the curated gateway dish (max hero, min risk).
    public let recipeSlug: String
    /// WP post id of the curated dish — the cook journal logs cooks against this
    /// (DUT-104) so "times cooked" aligns with the recipe detail.
    public let recipeID: Int
    public let dishTitle: String
    /// The "looks impressive, is actually forgiving" hook that earns the first try.
    public let whyThisDish: String
    /// The coached steps, in order (one or more per stage).
    public let steps: [Step]
    /// The "you did it" message at the lid-lift.
    public let celebrationMessage: String
    /// The invitation onward — home reps → the campfire.
    public let nextStepPrompt: String
    /// The dish's Dutch-oven bake temperature (°F) — drives the live coal count
    /// shown at the *fire* stage via ``CharcoalRecipeConverter``.
    public let ovenTempF: Int
    /// The Dutch-oven diameter (inches) the coal recommendation assumes — 12" is
    /// the common camp size.
    public let ovenDiameterInches: Int
    /// The dish's bake time in minutes — the duration of the live timer offered
    /// at the *cook* stage.
    public let bakeMinutes: Int
    /// The gear to round up at the *gather* stage (a curated checklist).
    public let gear: [String]
    /// The ingredients to round up at the *gather* stage (a curated checklist).
    public let ingredients: [String]

    public init(
        recipeSlug: String,
        recipeID: Int = 0,
        dishTitle: String,
        whyThisDish: String,
        steps: [Step],
        celebrationMessage: String,
        nextStepPrompt: String,
        ovenTempF: Int = 350,
        ovenDiameterInches: Int = 12,
        bakeMinutes: Int = 45,
        gear: [String] = [],
        ingredients: [String] = []
    ) {
        self.recipeSlug = recipeSlug
        self.recipeID = recipeID
        self.dishTitle = dishTitle
        self.whyThisDish = whyThisDish
        self.steps = steps
        self.celebrationMessage = celebrationMessage
        self.nextStepPrompt = nextStepPrompt
        self.ovenTempF = ovenTempF
        self.ovenDiameterInches = ovenDiameterInches
        self.bakeMinutes = bakeMinutes
        self.gear = gear
        self.ingredients = ingredients
    }

    /// The steps belonging to a given stage, in order.
    public func steps(in stage: Stage) -> [Step] {
        steps.filter { $0.stage == stage }
    }
}

extension GuidedCookout {

    /// The curated first cookout — Ned's own gateway dish, the **Dutch oven
    /// lasagna**: a showpiece that's genuinely hard to ruin, feeds a crowd, and
    /// makes a beginner look like a hero. Coaching copy is warm, beginner-first,
    /// and gives permission to be new at this (Ned burned plenty learning).
    /// Starter content — the voice gets refined with Ned, like the DO-101 guides.
    public static let firstCookout = GuidedCookout(
        recipeSlug: "dutch-oven-lasagna",
        recipeID: 1459,
        dishTitle: "Dutch Oven Lasagna",
        whyThisDish:
            "Lasagna looks like a showpiece, but in a Dutch oven it's one of the most "
            + "forgiving meals there is. You layer it, put the lid on, and walk away. It "
            + "feeds a crowd, everyone's impressed, and it's almost impossible to ruin. "
            + "That's exactly why it's the right first cookout.",
        steps: [
            Step(
                id: "gather-gear",
                stage: .gather,
                title: "Lay out your gear and ingredients",
                coaching:
                    "Get everything out before you start. It makes the whole thing feel "
                    + "easy. Don't worry about being precise; lasagna forgives a lot."
            ),
            Step(
                id: "light-coals",
                stage: .fire,
                title: "Get your coals going",
                coaching:
                    "This is the part that feels scary the first time. It isn't. Light a "
                    + "chimney of charcoal, and I'll tell you exactly how many coals and "
                    + "where to put them, bottom and lid. You've got this."
            ),
            Step(
                id: "layer-and-lid",
                stage: .cook,
                title: "Layer it, lid it, let it cook",
                coaching:
                    "Sauce, noodles, cheese. Layer it up, set the lid, and step away. The "
                    + "Dutch oven does the work. I'll keep the timer with you so you can "
                    + "relax and be with your people."
            ),
            Step(
                id: "lift-the-lid",
                stage: .celebrate,
                title: "Lift the lid",
                coaching:
                    "Bubbling, golden, smells incredible. You did that. Snap a photo before "
                    + "everyone digs in. You'll want to remember your first one."
            ),
        ],
        celebrationMessage:
            "That's it. You just cooked a Dutch oven lasagna. The first one is the "
            + "hardest, and you nailed it. (I burned plenty of mine learning.) "
            + "You're the cook now.",
        nextStepPrompt:
            "Make it again this week at home to lock it in, then take it to the campfire "
            + "and watch your family's faces.",
        ovenTempF: 375,
        ovenDiameterInches: 12,
        bakeMinutes: 45,
        gear: [
            "12-inch Dutch oven with a lid",
            "Lid lifter or a sturdy pair of pliers",
            "Charcoal briquettes + a chimney starter",
            "Heat-proof gloves",
            "A trivet or flat spot to set the oven on",
        ],
        ingredients: [
            "1 lb ground beef or Italian sausage",
            "1 jar (24 oz) marinara sauce",
            "9 no-boil lasagna noodles",
            "15 oz ricotta cheese",
            "2 cups shredded mozzarella",
            "½ cup grated parmesan",
            "1 egg",
            "Italian seasoning, salt + pepper",
        ]
    )
}
