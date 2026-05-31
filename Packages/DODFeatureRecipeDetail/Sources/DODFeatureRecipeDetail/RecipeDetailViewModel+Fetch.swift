import DODDomain
import DODSupport
import Foundation

/// Recipe-detail fetch + JSON-LD parse + article-classification helpers.
///
/// Extracted from ``RecipeDetailViewModel`` so the main class stays under
/// SwiftLint's `type_body_length` cap. The article-classification branch
/// (US-37 / CL-63 / T-640) added a meaningful chunk of fetch-path code
/// — putting it here keeps the view model focused on the public surface.
extension RecipeDetailViewModel {

    /// Fetch the rendered HTML page, try the JSON-LD parse, fall back to
    /// article classification on parse failure. Spec trace: AC-4.11
    /// (recipe path), AC-37.2 + AC-37.3 (article path).
    func fetchAndParse() async {
        let html: String
        do {
            html = try await dependencies.fetchHTML(for: canonicalURL)
        } catch {
            // The network fetch itself failed — no HTML to attempt either
            // parse against. Drop through to the legacy `.unavailable`
            // path. We don't mark `markJSONLDFailed` here because we don't
            // know yet whether the post page exists (it could be a
            // transient network failure rather than a missing-JSON-LD
            // post); the next pull-to-refresh's re-fetch decides.
            DODLog.network.error("recipe page fetch failed: \(String(describing: error))")
            loadState = .unavailable
            snackbarMessage = "Recipe unavailable."
            return
        }

        do {
            let parsed = try dependencies.parseJSONLD(
                html: html,
                merging: listItem,
                canonicalURL: canonicalURL
            )
            try await dependencies.mergeDetail(parsed)
            recipe = parsed
            // T-732 / CL-129 / AC-4.12: extract the recipe blurb (the
            // narrative HTML preceding the WPRM recipe card) and parse it
            // into native `ArticleBlock`s for the expand-collapse blurb
            // surface. Failure / empty result → `blurbBlocks` stays at
            // its default `[]` and the view falls back to the
            // collapsed-only state gracefully.
            let blurbHTML = ArticleBodyExtractor.extractRecipeBlurb(html: html)
            blurbBlocks =
                blurbHTML.isEmpty
                ? []
                : ArticleHTMLParser.parse(html: blurbHTML)
            loadState = .ready
            await loadRelated(forCategoryID: parsed.categoryIDs.first)
        } catch {
            // US-37 / CL-63 / AC-37.2 (T-640): JSON-LD parse failed.
            // Pre-T-640 this was the terminal failure path. Now we try
            // article-body extraction before falling through to
            // `.unavailable`.
            DODLog.network.error("recipe JSON-LD parse failed: \(String(describing: error))")
            await classifyAsArticleOrFail(html: html)
        }
    }

    /// US-37 / CL-63 / AC-37.2 + AC-37.3 (T-640): the JSON-LD parse failed.
    /// Attempt article-body extraction; on success classify the post as
    /// an article and transition to `.article(recipe)`. On failure fall
    /// through to the terminal `.unavailable` path with the same snackbar
    /// + auto-pop behavior the pre-T-640 implementation surfaced.
    func classifyAsArticleOrFail(html: String) async {
        let body = dependencies.extractArticleBody(html: html)
        guard !body.isEmpty else {
            try? await dependencies.markJSONLDFailed(id: listItem.id)
            loadState = .unavailable
            snackbarMessage = "Recipe unavailable."
            return
        }
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
        // Persist so subsequent opens hit the cache path. `mergeDetail`
        // on an article-kind recipe stamps `jsonLDFailedAt = .now` (the
        // kind discriminator per CL-63 decision 7).
        try? await dependencies.mergeDetail(article)
        recipe = article
        loadState = .article(article)
    }

    /// Load the related-recipes strip for the recipe path (AC-4.6).
    /// Articles skip this — the caller doesn't invoke `loadRelated` for
    /// `.article` load states per CL-63 decision 5 (articles are
    /// themselves often "related recipes" content; the strip would feel
    /// duplicative).
    func loadRelated(forCategoryID categoryID: Int?) async {
        guard let categoryID, await dependencies.isOnline() else {
            related = []
            return
        }
        let fetched = try? await dependencies.relatedRecipes(forCategoryID: categoryID)
        related = (fetched ?? []).filter { $0.id != listItem.id }
    }
}
