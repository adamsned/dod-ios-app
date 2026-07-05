import DODDomain
import DODSupport
import Foundation

/// DUT-577 — the pure, off-main classify/parse pipeline for the recipe-detail
/// fetch path. Extracted from ``RecipeDetailViewModel+Fetch.swift`` so that file
/// stays under SwiftLint's `file_length` cap. Everything here is `nonisolated`
/// (or `static`) and Sendable-in/out so it runs inside a `Task.detached`,
/// keeping the several-hundred-KB round-up page scan OFF the `@MainActor`. The
/// `@MainActor` `apply(classification:html:)` step (in `+Fetch`) consumes the
/// result. Classification is byte-identical to the pre-DUT-577 inline decision
/// tree (DUT-544/554/555), with `hasRecipeJSONLD` scanned exactly ONCE.
extension RecipeDetailViewModel {

    /// DUT-577 — Sendable result of the off-main classify/parse pipeline. Each
    /// case carries the fully-built value so the `@MainActor` `apply(...)` step
    /// only sets state + awaits the persistence seams. Ordering + branch
    /// selection are identical to the pre-DUT-577 inline logic (DUT-544/554/555).
    enum PageClassification: Sendable {
        /// JSON-LD parse yielded a renderable recipe (instructions present OR a
        /// `@type: Recipe` subject node). Carries the pre-parsed blurb blocks.
        case recipe(Recipe, blurbBlocks: [ArticleBlock])
        /// Article-classify path recovered a `.recipe`-kind `Recipe` from the
        /// WPRM card (recipe-subject card, or the DUT-555 card-only safety net).
        case cardRecipe(Recipe)
        /// Article-body extraction succeeded — render `.article`.
        case article(Recipe)
        /// Nothing renderable — terminal `.unavailable`.
        case unavailable
    }

    /// DUT-577 — the pure classify/parse decision tree, computed OFF the main
    /// actor. `nonisolated` + everything it touches is Sendable (`dependencies`,
    /// `listItem`, `canonicalURL`) so the body hops onto a detached task; the
    /// `@MainActor` caller only consumes the returned value. Mirrors the
    /// pre-DUT-577 `fetchAndParse` + `classifyAsArticleOrFail` flow exactly,
    /// with `hasRecipeJSONLD` scanned once (DUT-577 dedupe).
    nonisolated func classifyPage(html: String) async -> PageClassification {
        let dependencies = self.dependencies
        let listItem = self.listItem
        let canonicalURL = self.canonicalURL
        return await Task.detached(priority: .userInitiated) {
            // Scan the recipe-subject signal ONCE and thread it through both the
            // JSON-LD gate and the article-classify path (DUT-577 dedupe).
            let isRecipeSubject = dependencies.hasRecipeJSONLD(html: html)
            if let parsed = try? dependencies.parseJSONLD(
                html: html,
                merging: listItem,
                canonicalURL: canonicalURL
            ) {
                // DUT-538 (supersedes DUT-185): the WPRM-card parser recovers the
                // "How to Make" numbered steps from the post body when the card
                // itself carries no `wprm-recipe-instruction` rows (7 Can Soup),
                // so `parsed.instructions` is normally non-empty here.
                //
                // DUT-544: when a parse STILL yields no instructions, route to the
                // recipe path only if the page's SUBJECT is a recipe (a `@type:
                // Recipe` node). A round-up ARTICLE that embeds a WPRM card has a
                // card but no Recipe node, so it drops to the article path.
                if !parsed.instructions.isEmpty || isRecipeSubject {
                    // T-732 / CL-129 / AC-4.12 — extract the narrative blurb (the
                    // prose preceding the WPRM card) and parse it into native
                    // blocks. DUT-572 / CL-312: `paragraphLimit: .max`. DUT-582:
                    // pass `canonicalURL` so protocol-/root-relative body-image
                    // sources resolve to absolute http(s) URLs.
                    let blurbHTML = ArticleBodyExtractor.extractRecipeBlurb(
                        html: html,
                        paragraphLimit: .max
                    )
                    let blurbBlocks =
                        blurbHTML.isEmpty ? [] : ArticleHTMLParser.parse(html: blurbHTML, baseURL: canonicalURL)
                    return .recipe(parsed, blurbBlocks: blurbBlocks)
                }
            }
            return Self.classifyAsArticle(
                html: html,
                isRecipeSubject: isRecipeSubject,
                dependencies: dependencies,
                listItem: listItem,
                canonicalURL: canonicalURL
            )
        }.value
    }

    /// DUT-577 — the pure article-classification branch (was
    /// `classifyAsArticleOrFail`). Static + Sendable inputs so it runs inside the
    /// off-main `Task.detached`. Branch selection is byte-identical to the
    /// pre-DUT-577 logic (DUT-544/554/555); it just returns a value instead of
    /// mutating `@MainActor` state.
    nonisolated static func classifyAsArticle(
        html: String,
        isRecipeSubject: Bool,
        dependencies: RecipeDetailDependencies,
        listItem: RecipeListItem,
        canonicalURL: URL
    ) -> PageClassification {
        // DUT-544: build a recipe from the WPRM card only when the page's SUBJECT
        // is a recipe (its JSON-LD carries a `@type: Recipe` node). `isRecipeSubject`
        // is threaded in already-computed (DUT-577 dedupe) — no re-scan.
        let subjectCard =
            isRecipeSubject
            ? recipeFromWPRMCard(html: html, listItem: listItem, canonicalURL: canonicalURL)
            : nil
        if let subjectCard {
            return .cardRecipe(subjectCard)
        }
        // DUT-555: card-only-recipe safety net — a genuine recipe whose structured
        // data lives ONLY in the WPRM card (no Recipe node) is recovered here, but
        // ONLY when the card yields BOTH ingredients AND recovered steps, which
        // separates it from a round-up's embedded card (routed to the article path).
        let onlyCard =
            isRecipeSubject
            ? nil
            : cardOnlyRecipe(html: html, listItem: listItem, canonicalURL: canonicalURL)
        if let onlyCard {
            return .cardRecipe(onlyCard)
        }
        let body = dependencies.extractArticleBody(html: html)
        guard !body.isEmpty else { return .unavailable }
        let article = Recipe(
            id: listItem.id,
            slug: "",
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: canonicalURL,
            heroImage: listItem.heroImage,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: listItem.publishedAt,
            kind: .article,
            articleBodyHTML: body
        )
        return .article(article)
    }

    /// DUT-538: build a `.recipe`-kind `Recipe` straight from the WPRM card
    /// when the JSON-LD parse threw (or came back thin) but the page ships a
    /// structured recipe card. Returns nil when the card recovers NEITHER an
    /// ingredient NOR an instruction — a genuinely empty card offers nothing to
    /// render, so the caller falls through to the article-body path. List
    /// fields (id / title / image / dates) come from `listItem`; detail fields
    /// from the card. Times / nutrition / video stay nil — the card-only path
    /// is reached only when the JSON-LD that carries them was unavailable.
    ///
    /// DUT-577 — `nonisolated static` (inputs threaded in) so it runs inside the
    /// off-main classify task.
    nonisolated static func recipeFromWPRMCard(
        html: String,
        listItem: RecipeListItem,
        canonicalURL: URL
    ) -> Recipe? {
        let card = WPRMRecipeCardParser.parse(html: html)
        guard !card.ingredients.isEmpty || !card.instructions.isEmpty else {
            return nil
        }
        return recipe(fromCard: card, listItem: listItem, canonicalURL: canonicalURL)
    }

    /// DUT-555: build a `.recipe`-kind `Recipe` from the WPRM card for the
    /// card-only-recipe shape (no `@type: Recipe` JSON-LD node), but ONLY when
    /// the card yields BOTH non-empty ingredients AND recovered steps. That
    /// stricter both-lists gate — vs. ``recipeFromWPRMCard(html:listItem:canonicalURL:)``'s
    /// either-list gate — is what separates a genuine card-only recipe from a
    /// round-up ARTICLE that merely embeds a WPRM card: the round-up's card
    /// rarely carries both a full ingredient list AND recovered steps as the
    /// page's subject, so it stays on the article-body path. Returns nil when
    /// either list is empty.
    ///
    /// DUT-577 — `nonisolated static` (inputs threaded in) so it runs inside the
    /// off-main classify task.
    nonisolated static func cardOnlyRecipe(
        html: String,
        listItem: RecipeListItem,
        canonicalURL: URL
    ) -> Recipe? {
        let card = WPRMRecipeCardParser.parse(html: html)
        guard !card.ingredients.isEmpty, !card.instructions.isEmpty else {
            return nil
        }
        return recipe(fromCard: card, listItem: listItem, canonicalURL: canonicalURL)
    }

    /// Shared builder: map a parsed ``WPRMRecipeCardParser/Card`` onto a
    /// `.recipe`-kind `Recipe`, sourcing list fields (id / title / image / dates)
    /// from `listItem` and detail fields from the card. Times / nutrition / video
    /// stay nil — the card-only path is reached only when the JSON-LD that
    /// carries them was unavailable.
    ///
    /// DUT-577 — `nonisolated static` (inputs threaded in) so it runs inside the
    /// off-main classify task.
    nonisolated static func recipe(
        fromCard card: WPRMRecipeCardParser.Card,
        listItem: RecipeListItem,
        canonicalURL: URL
    ) -> Recipe {
        Recipe(
            id: listItem.id,
            slug: canonicalURL.lastPathComponent,
            title: listItem.title,
            excerpt: listItem.excerpt,
            canonicalURL: canonicalURL,
            heroImage: listItem.heroImage,
            heroImageLargeURL: nil,
            categoryIDs: listItem.categoryIDs ?? [],
            publishedAt: listItem.publishedAt,
            ingredients: card.ingredients.map { RecipeIngredient(text: $0) },
            instructions: card.instructions.enumerated().map { index, text in
                RecipeInstruction(step: index + 1, text: text)
            }
        )
    }
}
