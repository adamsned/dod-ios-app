import Foundation

/// Bundled content for the **Dutch Oven 101** beginner library.
///
/// Each `static let` is one ``TechniqueGuide``. They are split out of
/// `DutchOven101Library.swift` so neither file crosses the 400-line SwiftLint
/// cap; `DutchOven101Library.guides` composes them into the reading order.
///
/// The technique is genuinely accurate beginner cast-iron / Dutch-oven craft;
/// the voice is plain so Ned can refine it later. Spec trace: AC-52.1, CL-203.
extension DutchOven101Library {

    /// Preheating Your Dutch Oven — why and how to bring the pot up to heat.
    static let preheatingGuide = TechniqueGuide(
        slug: "preheating",
        title: "Preheating Your Dutch Oven",
        estimatedReadMinutes: 3,
        sections: [
            TechniqueGuide.Section(
                heading: "Why preheat at all?",
                body: """
                    Cast iron is slow to heat and slow to cool. That thermal mass \
                    is the whole point. A cold pot steals energy from your food, so \
                    meat steams and sticks instead of searing. Bringing the oven up \
                    to temperature first means food meets a hot, ready surface and \
                    cooks evenly from the moment it lands.
                    """
            ),
            TechniqueGuide.Section(
                heading: "How to do it",
                body: """
                    Set the empty (or lightly oiled) Dutch oven over your heat for a \
                    few minutes before adding anything. Over coals, give it longer \
                    than a stovetop. The heat builds gradually. You want it hot but \
                    not smoking hard. Add a thin film of oil and let it shimmer \
                    before the first ingredient goes in.
                    """
            ),
            TechniqueGuide.Section(
                heading: "The water-drop test",
                body: """
                    Flick a few drops of water onto the surface. If they sizzle and \
                    evaporate quickly, you are close. If they skitter and dance \
                    across the iron like little beads (the Leidenfrost effect), the \
                    pan is screaming hot. Back off the heat or you will scorch.
                    """
            ),
        ],
        keyTakeaways: [
            "A cold pot steams food; a preheated pot sears it.",
            "Let the oil shimmer before the first ingredient.",
            "Skittering water beads mean it is too hot, so back off.",
        ]
    )

    /// Lid On vs Lid Off — controlling moisture and browning with the lid.
    static let lidOnLidOffGuide = TechniqueGuide(
        slug: "lid-on-lid-off",
        title: "Lid On vs Lid Off",
        estimatedReadMinutes: 3,
        sections: [
            TechniqueGuide.Section(
                heading: "What the lid actually does",
                body: """
                    The lid traps steam. Trapped steam keeps food moist, speeds \
                    cooking, and (with coals on top) bakes from above. Take the lid \
                    off and that same steam escapes, letting liquid reduce and \
                    surfaces brown and crisp. Most of Dutch-oven cooking is just \
                    choosing when you want which.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Lid on for braises, stews, and baking",
                body: """
                    Keep the lid on when you want tenderness and moisture: a braise, \
                    a stew, a pot of beans, or anything baked with coals on the lid. \
                    Resist the urge to peek. Every time you lift the lid you lose \
                    heat and steam and add cooking time.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Lid off to reduce and brown",
                body: """
                    Pull the lid when a sauce is too thin or a top needs color. With \
                    the lid off, liquid evaporates and the dish concentrates and \
                    thickens. Finishing a braise uncovered for the last stretch is a \
                    classic way to deepen flavor and get a glossy sauce.
                    """
            ),
        ],
        keyTakeaways: [
            "Lid on traps steam: moist, faster, bakes from above.",
            "Lid off lets liquid reduce and surfaces brown.",
            "Stop peeking. Every lift costs heat and time.",
        ]
    )

    /// Brown Then Braise — the sear-first sequence that builds deep flavor.
    static let brownThenBraiseGuide = TechniqueGuide(
        slug: "brown-then-braise",
        title: "Brown Then Braise",
        estimatedReadMinutes: 4,
        sections: [
            TechniqueGuide.Section(
                heading: "Why browning comes first",
                body: """
                    Browning meat and vegetables triggers the Maillard reaction: \
                    hundreds of new flavor compounds form on a hot, dry surface. \
                    That deep, savory crust is flavor you cannot add later. A braise \
                    that skips the sear tastes flat and grey by comparison.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Brown in batches, not crowds",
                body: """
                    Pat the meat dry and salt it. Work in small batches so the pot \
                    stays hot. Crowd it and the released moisture drops the \
                    temperature, and everything steams instead of searing. Give each \
                    piece room and let it release on its own; if it sticks, it is \
                    not ready to turn yet.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Then build the braise",
                body: """
                    Once everything is browned and set aside, soften your aromatics \
                    in the fond, add liquid to come partway up the meat (not to \
                    cover it), return the meat, and bring it to a bare simmer. Lid \
                    on, low and slow, until fork-tender. Low heat is the secret: a \
                    hard boil makes meat tough and stringy.
                    """
            ),
        ],
        keyTakeaways: [
            "Browning builds flavor you can never add back later.",
            "Sear in batches so the pot never loses its heat.",
            "Braise at a bare simmer, never a hard boil.",
        ]
    )

    /// Resting Meat & Why — letting cooked meat settle before you cut it.
    static let restingMeatGuide = TechniqueGuide(
        slug: "resting-meat",
        title: "Resting Meat & Why",
        estimatedReadMinutes: 2,
        sections: [
            TechniqueGuide.Section(
                heading: "What resting does",
                body: """
                    As meat cooks, its muscle fibers tighten and push juices toward \
                    the center. Cut in immediately and that liquid floods your board. \
                    Rest the meat and the fibers relax and reabsorb the juices, so \
                    they stay in the meat where you want them. Carryover cooking also \
                    finishes the interior gently during the rest.
                    """
            ),
            TechniqueGuide.Section(
                heading: "How long, and how",
                body: """
                    Loosely tent the meat with foil and give a roast or large cut \
                    ten to twenty minutes; a steak or chop needs five or so. Loose, \
                    not wrapped tight: sealed foil traps steam and softens any crust \
                    you worked for. Rest is also free time: plate sides and make a \
                    pan sauce from the drippings while you wait.
                    """
            ),
        ],
        keyTakeaways: [
            "Resting lets juices redistribute instead of running out.",
            "Roughly 10–20 min for roasts, ~5 for steaks and chops.",
            "Tent loosely so you do not steam away the crust.",
        ]
    )

    /// Deglazing 101 — turning the browned fond into a sauce.
    static let deglazingGuide = TechniqueGuide(
        slug: "deglazing",
        title: "Deglazing 101",
        estimatedReadMinutes: 3,
        sections: [
            TechniqueGuide.Section(
                heading: "That brown stuff is flavor",
                body: """
                    After browning, the sticky brown layer welded to the bottom of \
                    the pot is called fond: concentrated, caramelized flavor. \
                    Deglazing dissolves it into liquid so it becomes the backbone of \
                    a sauce or braise instead of a scorched mess you scrub off later.
                    """
            ),
            TechniqueGuide.Section(
                heading: "How to deglaze",
                body: """
                    With the pot still hot, pour in a splash of liquid (stock, wine, \
                    beer, even water) and immediately scrape the bottom with a wooden \
                    spoon. The fond lifts and dissolves into the liquid. Let it bubble \
                    and reduce for a minute to cook off any raw alcohol and \
                    concentrate the flavor before you build the rest of the dish.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Don't let it burn first",
                body: """
                    Fond is gold; black is bitter. If the bottom is going from deep \
                    brown toward black, deglaze right away or pull the heat. Burnt \
                    fond will turn your whole sauce acrid. A little liquid at the \
                    right moment rescues it; waiting too long does not.
                    """
            ),
        ],
        keyTakeaways: [
            "Fond, the browned bottom layer, is concentrated flavor.",
            "Add liquid while hot and scrape it loose, then reduce.",
            "Deglaze before the fond blackens, or it turns bitter.",
        ]
    )

    /// Adapting Indoor Recipes for Outdoor Coals — translating an oven recipe
    /// to a Dutch oven over charcoal.
    static let adaptingIndoorRecipesGuide = TechniqueGuide(
        slug: "adapting-indoor-recipes",
        title: "Adapting Indoor Recipes for Outdoor Coals",
        estimatedReadMinutes: 4,
        sections: [
            TechniqueGuide.Section(
                heading: "Think in coals, not dials",
                body: """
                    An outdoor Dutch oven has no temperature dial. You set heat by \
                    how many charcoal briquettes you use and where you place them. A \
                    handy starting rule for a roughly 350°F oven is to use about \
                    twice the oven's diameter in briquettes: a 12-inch oven wants \
                    around 24 coals. Treat that as a starting point, then adjust by \
                    feel.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Place coals for the job",
                body: """
                    Where the coals go decides what the dish does. For even \
                    all-around heat (stews, roasts), split the coals roughly evenly \
                    between the lid and the bottom. For baking (breads, cobblers), \
                    go lid-heavy (more coals on top than underneath) so the top \
                    browns without scorching the bottom. Rotate the oven and lid a \
                    quarter turn now and then to even out hot spots.
                    """
            ),
            TechniqueGuide.Section(
                heading: "Adjust for wind and weather",
                body: """
                    Wind and cold steal heat fast, so on a blustery or cold day add \
                    a few coals and shelter the oven from the breeze. Coals also fade \
                    over time. For a long cook, light a fresh batch partway through \
                    so you can refresh the heat rather than watching it die. When in \
                    doubt, learn the feel: a properly heated lid is too hot to rest a \
                    bare hand on for long.
                    """
            ),
        ],
        keyTakeaways: [
            "Roughly 2× the oven's diameter in coals ≈ 350°F to start.",
            "Even heat: split coals; baking: load the lid heavier.",
            "Add coals for wind and cold; refresh them on long cooks.",
        ]
    )
}
