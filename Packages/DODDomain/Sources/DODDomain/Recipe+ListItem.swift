import Foundation

// DUT-534 Part 2 — the RecipeListItem → minimal Recipe seam for the Feed/Search
// card "Add to Shopping List" quick-add. A card carries a lightweight
// `RecipeListItem` (no ingredients), but the shared `ShoppingListAppender` takes
// a `Recipe`. This maps a list item into a minimal, ingredient-empty `Recipe`
// so the appender's hydrate-if-needed step can fetch + parse the ingredients the
// exact same way the Recipe-Detail / Saved-picker paths do
// (`recipeWithIngredients`, DUT-487) — no new fetch code, no duplicated logic.

extension Recipe {

    /// Build a minimal, ingredient-empty ``Recipe`` from a card's
    /// ``RecipeListItem``. Only the list-fetch fields the hydration seam needs
    /// (`id`, `title`, `excerpt`, `heroImage`, `publishedAt`, `categoryIDs`,
    /// `canonicalURL`) are carried; `ingredients` stays empty so the
    /// ``ShoppingListAppender`` hydrates them on append.
    ///
    /// `slug` is unknown from a list item (it isn't on the wire projection), so
    /// it defaults empty — the hydration path resolves the recipe by
    /// `canonicalURL`, never by slug. When the list item has no `canonicalURL`
    /// (a non-REST-sourced item), a sentinel host URL is used so the type's
    /// non-optional `canonicalURL` is satisfied; hydration against it simply
    /// yields no ingredients, which the appender folds into `.couldntLoad`.
    public init(listItem: RecipeListItem) {
        self.init(
            id: listItem.id,
            slug: "",
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: listItem.canonicalURL ?? Self.fallbackCanonicalURL,
            heroImage: listItem.heroImage,
            categoryIDs: listItem.categoryIDs ?? [],
            publishedAt: listItem.publishedAt
        )
    }

    /// Non-optional `canonicalURL` stand-in for a list item that carries none.
    /// Built with `if let` off a constant so the repo's `force_unwrapping`-as-
    /// error lint stays clean; the double fallback can never actually fail.
    private static var fallbackCanonicalURL: URL {
        URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
    }
}
