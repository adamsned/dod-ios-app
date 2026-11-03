public enum RecipeDietEvaluator {
    static let allergenKeywords: [Allergen: [String]] = [
        .nuts: ["almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut", "peanut"],
        .shellfish: ["shrimp", "crab", "lobster", "clam", "oyster", "scallop", "mussel"],
        .eggs: ["egg", "mayonnaise"],
        .dairy: ["milk", "butter", "cheese", "cream", "yogurt", "buttermilk"],
        .gluten: ["flour", "bread", "pasta", "noodle", "breadcrumb", "biscuit", "cracker"],
        .soy: ["soy", "tofu", "edamame", "miso"],
        .fish: ["salmon", "tuna", "cod", "anchovy", "trout", "catfish"],
    ]
}
