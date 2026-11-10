/// DUT-995 — classifies a Cook Mode step as safe for a child to help with.
/// Pure on-device keyword scan (same static-keyword precedent as
/// ``IngredientAisleClassifier``). Conservative: any grown-up keyword => not kid-safe.
public enum KidSafeStepClassifier {

    /// True when the step text carries no knife / heat / hot-surface language.
    public static func isKidSafe(_ text: String) -> Bool {
        let haystack = text.lowercased()
        return !grownUpKeywords.contains(where: haystack.contains)
    }

    static let grownUpKeywords: [String] = [
        "knife", "chop", "dice", "mince", "slice", "cut ", "carve", "grate", "peel",
        "hot", "boil", "sear", "saute", "sauté", "fry", "broil", "bake", "roast",
        "oven", "stove", "burner", "flame", "coal", "briquette", "charcoal",
        "preheat", "pre-heat", "lid", "skillet", "dutch oven", "simmer", "deglaze",
        "°", "degrees", "mandoline", "blender", "thermometer",
    ]
}
