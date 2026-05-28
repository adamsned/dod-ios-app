import DODDomain
import Foundation

/// Classifies a single ingredient line into an ``Aisle`` via a static
/// keyword + phrase map.
///
/// **Strategy: static keyword map (CL-67).** ~80 hand-curated stems
/// cover the dad-tested DOD recipe corpus; multi-word phrases handle
/// the cases where a single token would mis-route (e.g. `"bell pepper"`
/// belongs in Produce but the bare `"pepper"` is a Spices stem).
/// Unknown lines fall through to ``Aisle/other`` — the CL-67 escalation
/// trigger watches the `.other` share via the AC-39.10 telemetry event.
///
/// **Bell-pepper carve-out (load-bearing):** the phrase scan runs first
/// so `"1 red bell pepper, diced"` resolves to ``Aisle/produce`` before
/// the single-token loop sees `"pepper"` (which would route to
/// ``Aisle/spices`` via the black/white-pepper stem). The phrase map
/// is intentionally ordered so the most-specific phrase wins; if a
/// future curator adds another multi-word phrase that collides with a
/// single-token stem, document the carve-out here.
///
/// **Algorithm:**
/// 1. Lowercase with `.current` locale (constitution §10 hygiene —
///    avoids the Turkish dotted-i edge case on user-facing text).
/// 2. Strip common punctuation (`,`, `.`, `(`, `)`, `;`, `:`) so
///    `"garlic, minced"` tokenizes cleanly to `["garlic", "minced"]`.
/// 3. Scan the multi-word phrase map first (preserves order); first hit
///    wins. The phrase substring match is over the full punctuation-
///    stripped lowercased text so quantity/unit prefixes don't block
///    the match.
/// 4. Tokenize on whitespace; scan tokens left-to-right against the
///    single-word keyword map; first hit wins.
/// 5. No hit → ``Aisle/other``.
///
/// **Pure value-in, value-out.** No state, no side effects, no
/// dependencies on Foundation beyond `String.lowercased(with:)`.
/// Tests call ``classify(_:)`` directly — no protocol surface (CL-67's
/// explicit YAGNI call).
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping), AC-39.10 (telemetry
/// uses the classified ``Aisle/rawValue``), CL-67 (strategy +
/// keyword-map design intent).
public enum AisleClassifier {

    /// Returns the best-guess ``Aisle`` for a raw recipe-ingredient line.
    ///
    /// - Parameter ingredientText: One verbatim line from
    ///   `RecipeIngredient.text` (e.g. `"1 1/2 cups whole milk"`).
    /// - Returns: The classified ``Aisle`` — ``Aisle/other`` if no
    ///   keyword in the v1 map matches.
    public static func classify(_ ingredientText: String) -> Aisle {
        let normalized = normalize(ingredientText)
        guard !normalized.isEmpty else { return .other }

        // Phrase scan first — multi-word phrases beat single-word stems
        // (the bell-pepper carve-out lives here).
        for (phrase, aisle) in phraseMap where normalized.contains(phrase) {
            return aisle
        }

        // Single-token scan. First hit wins (left-to-right walk of the
        // tokenized line so the first recognized food noun anchors the
        // aisle — quantity/unit prefixes don't appear in the keyword
        // map and are skipped naturally).
        let tokens = normalized.split(whereSeparator: { $0.isWhitespace })
        for token in tokens {
            if let aisle = keywordMap[String(token)] {
                return aisle
            }
        }
        return .other
    }

    /// Lowercase + punctuation-strip the input. Locale-aware lowercasing
    /// per CL-67 (Turkish dotted-i edge case).
    private static func normalize(_ text: String) -> String {
        var lowered = text.lowercased(with: .current)
        for character in punctuationToStrip {
            lowered = lowered.replacingOccurrences(of: String(character), with: " ")
        }
        return lowered
    }

    private static let punctuationToStrip: [Character] = [
        ",", ".", "(", ")", ";", ":",
    ]

    /// Multi-word phrases scanned **before** single-token keywords.
    /// Order matters: the first matching phrase wins, so more-specific
    /// phrases come first (e.g. `"bell pepper"` ahead of any single
    /// `"pepper"` route). Implemented as an array of tuples (not a
    /// dictionary) to preserve curation order.
    private static let phraseMap: [(String, Aisle)] = [
        // Produce — multi-word fresh items that would mis-route on a
        // single-token lookup.
        ("bell pepper", .produce),
        ("sweet potato", .produce),
        ("green onion", .produce),
        ("red onion", .produce),
        ("yellow onion", .produce),
        ("white onion", .produce),
        // "cloves garlic" is the common DOD-recipe form ("3 cloves
        // garlic") where "cloves" is the *unit* (a garlic-bulb segment),
        // not the dried spice. Phrase-match it ahead of the spices
        // "clove" stem so produce wins.
        ("cloves garlic", .produce),
        ("clove garlic", .produce),
        ("cloves of garlic", .produce),
        // Meat + Seafood compound terms.
        ("ground beef", .meat),
        ("ground turkey", .meat),
        ("ground chicken", .meat),
        ("ground pork", .meat),
        ("chicken breast", .meat),
        ("chicken thigh", .meat),
        ("pork chop", .meat),
        // Pantry compound terms.
        ("soy sauce", .pantry),
        ("olive oil", .pantry),
        ("vegetable oil", .pantry),
        ("canola oil", .pantry),
        ("tomato sauce", .pantry),
        ("tomato paste", .pantry),
        ("brown sugar", .pantry),
        ("powdered sugar", .pantry),
        ("white sugar", .pantry),
        ("vanilla extract", .pantry),
        ("almond extract", .pantry),
        ("peanut butter", .pantry),
        ("maple syrup", .pantry),
        ("hot sauce", .pantry),
        ("worcestershire sauce", .pantry),
        ("apple cider vinegar", .pantry),
        ("balsamic vinegar", .pantry),
        ("red wine vinegar", .pantry),
        ("baking powder", .pantry),
        ("baking soda", .pantry),
        // Spices compound terms — these MUST sit before the bare
        // `"pepper"` single-token lookup so e.g. `"black pepper"`
        // routes to spices, while the phraseMap `"bell pepper"` rule
        // above sends produce-bell-peppers to produce.
        ("garlic powder", .spices),
        ("onion powder", .spices),
        ("chili powder", .spices),
        ("black pepper", .spices),
        ("white pepper", .spices),
        ("cayenne pepper", .spices),
        ("crushed red pepper", .spices),
        ("red pepper flakes", .spices),
        ("bay leaf", .spices),
        ("bay leaves", .spices),
        // Dried-clove spice form ("ground cloves"). The bare "cloves"
        // single-token is intentionally not in the keyword map because
        // it's most often a *unit* for garlic (handled above).
        ("ground cloves", .spices),
        ("ground clove", .spices),
        // Bakery compound terms — "flour tortillas" would otherwise
        // route to pantry on the bare "flour" stem.
        ("flour tortilla", .bakery),
        ("corn tortilla", .bakery),
        ("dinner roll", .bakery),
        ("hamburger bun", .bakery),
        ("hot dog bun", .bakery),
        // Frozen compound terms.
        ("ice cream", .frozen),
        ("frozen peas", .frozen),
        ("frozen vegetables", .frozen),
        ("frozen corn", .frozen),
        ("frozen berries", .frozen),
        // Dairy compound terms.
        ("sour cream", .dairy),
        ("cream cheese", .dairy),
        ("heavy cream", .dairy),
        ("whipping cream", .dairy),
        ("cottage cheese", .dairy),
    ]

    /// Single-token keyword map. ~80 entries grouped by aisle. The
    /// keyword is the lowercased stem; matches are exact-token (no
    /// substring / no stemming algorithm — Swift's basic Character set
    /// keeps us deterministic).
    ///
    /// Curation rationale per aisle:
    /// - **Produce** — fresh form only (onion, garlic, fresh herbs,
    ///   every common leafy green + fruit). Dried herbs go to Spices.
    /// - **Pantry** — shelf-stable cooking staples: oils, vinegars,
    ///   canned goods, dry pasta, rice, flour, sugar, condiments,
    ///   nut butters.
    /// - **Dairy + Eggs** — refrigerated dairy, eggs, butter, cheese.
    /// - **Meat + Seafood** — fresh meat + fish stems.
    /// - **Spices** — dried herbs and ground spices.
    /// - **Bakery** — fresh bread + tortillas + buns.
    /// - **Frozen** — frozen-only stems (ice cream, frozen sides).
    private static let keywordMap: [String: Aisle] = [
        // Produce (fresh)
        "onion": .produce,
        "garlic": .produce,
        "carrot": .produce,
        "carrots": .produce,
        "celery": .produce,
        "potato": .produce,
        "potatoes": .produce,
        "tomato": .produce,
        "tomatoes": .produce,
        "lettuce": .produce,
        "spinach": .produce,
        "kale": .produce,
        "broccoli": .produce,
        "cauliflower": .produce,
        "cucumber": .produce,
        "zucchini": .produce,
        "mushroom": .produce,
        "mushrooms": .produce,
        "avocado": .produce,
        "lemon": .produce,
        "lemons": .produce,
        "lime": .produce,
        "limes": .produce,
        "apple": .produce,
        "apples": .produce,
        "banana": .produce,
        "bananas": .produce,
        "berries": .produce,
        "strawberries": .produce,
        "blueberries": .produce,
        "raspberries": .produce,
        "ginger": .produce,
        "cilantro": .produce,
        "parsley": .produce,
        "basil": .produce,
        "mint": .produce,
        "rosemary": .produce,
        "thyme": .produce,
        "scallion": .produce,
        "scallions": .produce,
        "shallot": .produce,
        "shallots": .produce,
        "jalapeno": .produce,
        "jalapenos": .produce,

        // Pantry (shelf-stable)
        "flour": .pantry,
        "sugar": .pantry,
        "rice": .pantry,
        "pasta": .pantry,
        "spaghetti": .pantry,
        "noodles": .pantry,
        "beans": .pantry,
        "lentils": .pantry,
        "chickpeas": .pantry,
        "oats": .pantry,
        "oil": .pantry,
        "vinegar": .pantry,
        "broth": .pantry,
        "stock": .pantry,
        "honey": .pantry,
        "ketchup": .pantry,
        "mustard": .pantry,
        "mayonnaise": .pantry,
        "mayo": .pantry,
        "salsa": .pantry,
        "cornstarch": .pantry,
        "cocoa": .pantry,
        "chocolate": .pantry,

        // Dairy + Eggs
        "milk": .dairy,
        "butter": .dairy,
        "cheese": .dairy,
        "cheddar": .dairy,
        "mozzarella": .dairy,
        "parmesan": .dairy,
        "yogurt": .dairy,
        "egg": .dairy,
        "eggs": .dairy,
        "cream": .dairy,
        "buttermilk": .dairy,

        // Meat + Seafood
        "chicken": .meat,
        "beef": .meat,
        "pork": .meat,
        "bacon": .meat,
        "sausage": .meat,
        "ham": .meat,
        "turkey": .meat,
        "lamb": .meat,
        "steak": .meat,
        "shrimp": .meat,
        "salmon": .meat,
        "tuna": .meat,
        "cod": .meat,
        "fish": .meat,

        // Spices (dried / ground)
        "salt": .spices,
        "pepper": .spices,
        "paprika": .spices,
        "cumin": .spices,
        "oregano": .spices,
        "cinnamon": .spices,
        "nutmeg": .spices,
        "turmeric": .spices,
        "coriander": .spices,
        "dill": .spices,
        "sage": .spices,
        "tarragon": .spices,

        // Bakery
        "bread": .bakery,
        "rolls": .bakery,
        "buns": .bakery,
        "bagel": .bakery,
        "bagels": .bakery,
        "tortilla": .bakery,
        "tortillas": .bakery,
        "croissant": .bakery,
        "croissants": .bakery,

        // Frozen (single-token frozen-only stems are rare; most frozen
        // items are caught by the "frozen X" phrases above).
        "popsicles": .frozen,
    ]
}
