import Foundation

/// Classifies a raw recipe-ingredient line (e.g. the `text` field of
/// ``RecipeIngredient``) into a coarse-grained store aisle so the Shopping
/// List can group items the way a cook walks a grocery store.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping), AC-39.12 (no network egress
/// — the classifier is pure on-device). CL-67 (static keyword-map strategy,
/// chosen over a tagged dictionary, fuzzy matching, or WP-side classification
/// for v1). CL-80 (the logic-core split — this type ships ahead of the UI as
/// T-680a). Constitution §6 L1 mandate (every domain transform owns tests).
///
/// **Why a static keyword map and not ML / a tagged dictionary (CL-67):** the
/// v1 classifier is a `[String: Aisle]` literal of common ingredient stems
/// plus a `default → .other` fallback. The keyword map ships in source (NOT a
/// JSON resource — a static dictionary the compiler folds into a constant
/// beats a runtime load + parse + cache for a table this small and
/// human-readable). The `.other` share of inserted rows is the documented
/// telemetry signal (AC-39.10) that escalates to a richer classifier if the
/// keyword map's miss rate climbs.
///
/// **Why an enum + static func and not a protocol (CL-67):** the classifier
/// has zero dependencies, zero side effects, and zero state. A DI protocol
/// surface would be over-engineering for a pure value-in/value-out function;
/// tests call ``classify(_:)`` directly.
///
/// **Matching:** the ingredient line is lowercased (locale-aware per
/// constitution §10 hygiene) and each keyword is tested as a **substring**.
/// `"2 cups diced YELLOW ONION"` matches `"onion"` → `.produce`; `"1 tsp
/// smoked paprika"` matches `"paprika"` → `.spices`. The first matching
/// keyword (scanning longest-keyword-first so `"ground beef"` beats a bare
/// `"beef"` only when both map to the same aisle anyway, and so multi-word
/// stems aren't shadowed by their fragments) wins; no match returns `.other`.
public enum IngredientAisleClassifier {

    /// Coarse-grained store aisle for an ingredient. Raw-value strings are the
    /// telemetry payload per AC-39.10 and the persisted `aisleRaw` per CL-74.
    ///
    /// The logic-core v1 set (T-680a / CL-80) is the six aisles below; the
    /// full nine-case render/persistence set (`meatSeafood` / `bakery` /
    /// `frozen` / `beverages`) is the T-680b concern reconciled against CL-74.
    /// `Aisle` co-locates here per CL-80 rather than in `DODDomain`; T-681 /
    /// T-680b may hoist it as a mechanical move with no behavior change.
    public enum Aisle: String, CaseIterable, Sendable {
        case produce
        case meat
        case dairy
        case pantry
        case spices
        case other
    }

    /// Classify a raw ingredient line into its store aisle.
    ///
    /// Case-insensitive substring match against ``keywordMap``; returns
    /// ``Aisle/other`` when no keyword is found. Pure and deterministic.
    ///
    /// - Parameter ingredientName: One ingredient line (raw `RecipeIngredient`
    ///   text — may carry a leading quantity, a unit, and trailing qualifiers,
    ///   e.g. `"1 ½ pounds boneless skinless chicken thighs"`).
    /// - Returns: The matched ``Aisle``, or ``Aisle/other`` if nothing matches.
    public static func classify(_ ingredientName: String) -> Aisle {
        let haystack = ingredientName.lowercased(with: .current)
        guard !haystack.isEmpty else { return .other }
        for keyword in sortedKeywords where haystack.contains(keyword) {
            // `keywordMap[keyword]` is guaranteed present — `sortedKeywords`
            // is derived from the map's keys.
            if let aisle = keywordMap[keyword] { return aisle }
        }
        return .other
    }

    // MARK: - Keyword map

    /// Keywords sorted longest-first so a multi-word stem (`"ground beef"`,
    /// `"vanilla extract"`, `"olive oil"`) is tested before any single-word
    /// fragment of it. Computed once.
    private static let sortedKeywords: [String] = keywordMap.keys.sorted {
        $0.count > $1.count
    }

    /// The v1 static keyword map (CL-67). ~60 common ingredient stems hand
    /// curated from a US grocery-store walk, grouped by aisle and alphabetical
    /// inside each block so a future curator can extend it without re-deriving
    /// the intent.
    ///
    /// Curation rationale (CL-67):
    /// - **Produce**: onion / garlic / every common fresh vegetable, leafy
    ///   green, fresh herb, and common fruit. Fresh herbs live here; *dried*
    ///   herbs go under Spices.
    /// - **Meat**: beef / pork / poultry / fish / seafood. (The render layer's
    ///   nine-case set splits this into "Meat & Seafood" per AC-39.4; the
    ///   logic core folds both into `.meat`.)
    /// - **Dairy**: milk / cheese / butter / yogurt / cream / eggs. Eggs sit
    ///   with dairy because that's where the grocery store puts them.
    /// - **Pantry**: flour / sugar / oils / canned goods / pasta / rice /
    ///   baking staples / condiments / stocks. The catch-all "center store."
    /// - **Spices**: dried/ground seasonings and extracts used by the spoonful.
    /// - **Other**: the fallback for anything unmatched (AC-39.4 permissive
    ///   bucket — unknown brands, regional terms).
    private static let keywordMap: [String: Aisle] = [
        // MARK: Produce
        "apple": .produce,
        "avocado": .produce,
        "banana": .produce,
        "basil": .produce,
        "bell pepper": .produce,
        "broccoli": .produce,
        "carrot": .produce,
        "celery": .produce,
        "cilantro": .produce,
        "cucumber": .produce,
        "garlic": .produce,
        "ginger": .produce,
        "green onion": .produce,
        "jalapeno": .produce,
        "lemon": .produce,
        "lettuce": .produce,
        "lime": .produce,
        "mushroom": .produce,
        "onion": .produce,
        "parsley": .produce,
        "potato": .produce,
        "scallion": .produce,
        "spinach": .produce,
        "tomato": .produce,
        "zucchini": .produce,

        // MARK: Meat & Seafood
        "bacon": .meat,
        "beef": .meat,
        "chicken": .meat,
        "ground beef": .meat,
        "ground turkey": .meat,
        "ham": .meat,
        "pork": .meat,
        "salmon": .meat,
        "sausage": .meat,
        "shrimp": .meat,
        "steak": .meat,
        "tuna": .meat,
        "turkey": .meat,

        // MARK: Dairy
        "butter": .dairy,
        "cheddar": .dairy,
        "cheese": .dairy,
        "cream cheese": .dairy,
        "egg": .dairy,
        "heavy cream": .dairy,
        "milk": .dairy,
        "mozzarella": .dairy,
        "parmesan": .dairy,
        "sour cream": .dairy,
        "yogurt": .dairy,

        // MARK: Pantry
        "baking powder": .pantry,
        "baking soda": .pantry,
        "bread": .pantry,
        "broth": .pantry,
        "brown sugar": .pantry,
        "flour": .pantry,
        "honey": .pantry,
        "ketchup": .pantry,
        "mayonnaise": .pantry,
        "mustard": .pantry,
        "oats": .pantry,
        "olive oil": .pantry,
        "pasta": .pantry,
        "rice": .pantry,
        "soy sauce": .pantry,
        "stock": .pantry,
        "sugar": .pantry,
        "tomato paste": .pantry,
        "vanilla extract": .pantry,
        "vegetable oil": .pantry,
        "vinegar": .pantry,

        // MARK: Spices
        "black pepper": .spices,
        "cayenne": .spices,
        "chili powder": .spices,
        "cinnamon": .spices,
        "cumin": .spices,
        "garlic powder": .spices,
        "oregano": .spices,
        "paprika": .spices,
        "salt": .spices,
        "thyme": .spices,
    ]
}
