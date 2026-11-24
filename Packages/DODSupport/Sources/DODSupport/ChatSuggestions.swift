import Foundation

/// DUT-2893 — suggestion chips for the on-device chats.
///
/// Pure and deterministic (no model call), so chips appear instantly, work
/// offline, and are unit-tested. Copy is sentence-case questions with no em
/// dashes (user-facing).
public enum ChatSuggestions {

    // MARK: - Ask the Recipe (built from the recipe)

    /// Questions tailored to one recipe, most useful first, at most `limit`.
    ///
    /// Signals, in priority order: a common ingredient swap, coals vs. oven
    /// heat, meat or fish doneness, scaling from the serving count, make-ahead
    /// for long or braise/bake style recipes, then leftovers as the fallback.
    public static func forRecipe(
        title: String,
        ingredients: [String],
        steps: [String],
        servings: Int?,
        limit: Int = 4
    ) -> [String] {
        let ingredientText = ingredients.joined(separator: "\n").lowercased()
        let stepText = steps.joined(separator: "\n").lowercased()
        let titleText = title.lowercased()
        var out: [String] = []

        if let swap = firstSwappable(in: ingredients) {
            out.append("What can I use instead of \(swap)?")
        }
        if containsAny(stepText, ["coal", "briquette", "campfire", "charcoal"]) {
            out.append("How many coals do I need on top and bottom?")
        } else if containsAny(stepText, ["°f", "degrees", "oven", "preheat"]) {
            out.append("Can I make this over a campfire with coals?")
        }
        if let protein = firstMatch(in: ingredientText, from: proteins) {
            out.append("How do I know when the \(protein) is done?")
        }
        if let servings, servings >= 8 {
            out.append("How do I make half of this?")
        } else {
            out.append("How do I double this recipe?")
        }
        if steps.count >= 6 || containsAny(titleText, makeAheadWords) {
            out.append("Can I make this ahead?")
        }
        out.append("How do I store and reheat leftovers?")

        var seen: Set<String> = []
        return Array(out.filter { seen.insert($0).inserted }.prefix(limit))
    }

    // MARK: - Ask Dutch Oven Daddy (general)

    /// The general cast iron / Dutch oven question pool.
    public static let generalPool = [
        "How do I season a new Dutch oven?",
        "How do I get rust off cast iron?",
        "How many coals for 350°F?",
        "Can I use soap on cast iron?",
        "Why is my food sticking?",
        "How do I clean burnt-on food?",
        "Can I cook tomatoes in cast iron?",
        "What size Dutch oven should I get?",
        "How do I bake bread in a Dutch oven?",
        "Enameled or bare cast iron?",
        "How do I keep a campfire meal from burning?",
        "How do I store cast iron?",
    ]

    /// `count` questions from ``generalPool`` for the given day: a different,
    /// stable set each day (same day, same chips).
    public static func general(dayKey: String, count: Int = 4) -> [String] {
        let pool = generalPool
        guard !pool.isEmpty else { return [] }
        let start = Int(fnv1a(dayKey) % UInt64(pool.count))
        return (0..<min(count, pool.count)).map { pool[(start + $0) % pool.count] }
    }

    /// "yyyy-MM-dd" for `date` in the local calendar.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Shared

    /// Chips not yet asked in this conversation (case-insensitive).
    public static func remaining(_ suggestions: [String], askedTexts: [String]) -> [String] {
        let asked = Set(askedTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return suggestions.filter { !asked.contains($0.lowercased()) }
    }

    // MARK: - Private

    /// Ingredient keyword -> the name used in the question. Checked in the
    /// recipe's ingredient order, so the first swappable line wins.
    private static let swappable: [(keyword: String, name: String)] = [
        ("buttermilk", "buttermilk"),
        ("heavy cream", "heavy cream"),
        ("heavy whipping cream", "heavy cream"),
        ("sour cream", "sour cream"),
        ("self-rising flour", "self-rising flour"),
        ("self rising flour", "self-rising flour"),
        ("cake flour", "cake flour"),
        ("brown sugar", "brown sugar"),
        ("white wine", "white wine"),
        ("red wine", "red wine"),
        ("panko", "panko"),
        ("bread crumbs", "bread crumbs"),
        ("cornstarch", "cornstarch"),
        ("cream cheese", "cream cheese"),
        ("evaporated milk", "evaporated milk"),
        ("sweetened condensed milk", "sweetened condensed milk"),
        ("shallot", "shallots"),
        ("egg", "eggs"),
        ("peanut butter", "peanut butter"),
        ("butter", "butter"),
    ]

    private static let proteins = [
        "chicken", "pork", "beef", "steak", "brisket", "venison", "turkey", "lamb",
        "sausage", "shrimp", "salmon", "fish", "roast",
    ]

    private static let makeAheadWords = [
        "casserole", "soup", "stew", "chili", "cobbler", "bread", "roast", "braise", "pot pie",
    ]

    private static func firstSwappable(in ingredients: [String]) -> String? {
        for line in ingredients.map({ $0.lowercased() }) {
            if let hit = swappable.first(where: { containsWord(line, $0.keyword) }) { return hit.name }
        }
        return nil
    }

    private static func firstMatch(in text: String, from words: [String]) -> String? {
        words.first { containsWord(text, $0) }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    /// Whole-word match (plural allowed): "egg" matches "2 eggs" but not
    /// "eggplant", "butter" doesn't match "buttermilk".
    private static func containsWord(_ text: String, _ word: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word))s?\\b", options: .regularExpression) != nil
    }

    private static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}
