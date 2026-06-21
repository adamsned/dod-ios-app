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
            // DUT-185: WP Recipe Maker now renders steps client-side and redacts
            // them from every scrapable source (JSON-LD, server HTML, the WPRM
            // REST API), so some recipes (e.g. Dutch Oven 7 Can Soup) parse with
            // an EMPTY instruction list — the recipe layout would show a blank
            // Instructions section. The steps still live in the post's
            // "How to Make" body, so fall back to the article-body path (which
            // renders the full post) rather than a step-less recipe. A recipe
            // that DOES parse instructions is unchanged.
            guard !parsed.instructions.isEmpty else {
                await classifyAsArticleOrFail(html: html)
                return
            }
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

    /// DUT-185: cache-hit dispatch for `.recipe`-kind posts. A recipe cached
    /// with NO instructions hit the WPRM-redaction gap — its steps render
    /// client-side and are stripped from every scrapable source (see
    /// ``fetchAndParse``), so it must re-fetch to re-classify onto the
    /// article-body path where the "How to Make" steps live. **Guarded on
    /// ``isOnline()``:** offline we keep serving the cached (step-less but
    /// ingredient-bearing) view rather than downgrading to "Recipe unavailable"
    /// — the re-fetch can only help when it can actually run.
    func hydrateRecipeOrReclassify(_ cached: Recipe) async {
        if cached.instructions.isEmpty, await dependencies.isOnline() {
            await fetchAndParse()
        } else {
            await hydrateCachedRecipe(cached)
        }
    }

    /// T-736 / CL-133: cache-hit hydration helper for the `.recipe` kind —
    /// extracted out of `onAppear()` so the cache-hit branch stays terse
    /// and the view-model file stays under the file-length cap. Mirrors the
    /// pre-T-736 inline `.ready` + `loadRelated` sequence, plus a
    /// **fire-and-forget** `refreshBlurbBlocks` Task that closes the
    /// AC-4.12 cache-hit blurb gap without blocking `onAppear()` on a
    /// network call. The await-inline version broke the L5 E2E journey
    /// suite under CI (REG-37 / T-737-fixforward) — the test thread saw
    /// the Ingredients header miss its `waitForExistence` timeout because
    /// the `await` held `onAppear()` open across a slow live-API fetch.
    func hydrateCachedRecipe(_ cached: Recipe) async {
        loadState = .ready
        await loadRelated(forCategoryID: cached.categoryIDs.first)
        // Fire-and-forget: the cached view is already on screen via
        // `.ready`; the rich blurb arrives in a later frame when the
        // background fetch lands. Holding `onAppear()` open on this would
        // serialize subsequent UI work behind a network call (REG-37).
        let url = canonicalURL
        Task { [weak self] in
            await self?.refreshBlurbBlocks(forCanonicalURL: url)
            // DUT-53: self-heal a cached recipe whose ingredients are empty
            // — parsed before the DUT-42 WPRM fallback existed, or fixed on
            // the site since it was cached. No-op when ingredients present.
            await self?.backfillIngredientsIfEmpty()
        }
    }

    /// T-736 / CL-133 / AC-4.12 (amended): refresh `blurbBlocks` on a cache-
    /// hit re-open. `viewModel.blurbBlocks` is view-local state that only
    /// ever populates via the fresh-fetch path (`fetchAndParse()` line 47-51);
    /// the cache-hit fast path in `onAppear()` returns via `loadState = .ready`
    /// WITHOUT touching it, so on every re-open of a previously-cached recipe
    /// the array holds its initializer default `[]` and the view renders the
    /// empty-`blurbBlocks` fallback (`Text(strippedExcerpt)` per
    /// `RecipeDetailView+Blurb.swift` lines 124-134) instead of the rich
    /// `ArticleBlocksView` path. Spencer's "lots of recipes missing the rich
    /// blurb" perception came from this gap — the T-736 audit (50 newest +
    /// 50 oldest + 100 mid-catalog recipes on `dutchovendaddy.com`, 2026-05-31)
    /// confirmed extractor coverage is effectively 100% (50/50, 50/50, 99/100
    /// with one transient HTTP fail), so the gap is exclusively in the cache-
    /// hit branch of `onAppear()`, not in the extractor or the parser.
    ///
    /// **Contract.** Four steps:
    /// 1. Gate on `await dependencies.isOnline()`. Offline cache-hits skip
    ///    the network call entirely — the fallback `Text` path is an
    ///    acceptable render when there's no fresh data anyway, and issuing
    ///    a network call we know will fail wastes battery + adds spurious
    ///    error-log noise.
    /// 2. `try?` `dependencies.fetchHTML(for: canonicalURL)`. Fail-silent on
    ///    transient errors — the cached view is already on screen, surfacing
    ///    a snackbar would feel like the app is broken in a context where
    ///    it manifestly is not. The next online open re-attempts the refresh.
    ///    Matches the `loadRatingsAndComments` no-op-on-failure pattern
    ///    (REG-14 / AC-14.6).
    /// 3. Run the same `ArticleBodyExtractor.extractRecipeBlurb` +
    ///    `ArticleHTMLParser.parse` pipeline `fetchAndParse()` uses (line 47).
    /// 4. Assign `blurbBlocks` ONLY if the parsed result is non-empty. The
    ///    non-empty guard prevents a transient parse failure from
    ///    overwriting a previously-successful population with `[]`,
    ///    downgrading the view from rich-blurb to fallback-`Text` on a
    ///    subsequent refresh. (The view-model lives for the duration of
    ///    `RecipeDetailView`; a second `onAppear` from a deep-link push
    ///    re-runs the refresh, so worst case is one stale render — but the
    ///    guard means an empty parse never *downgrades* a previously-
    ///    successful render.)
    ///
    /// **Not called for articles.** Articles persist `articleBodyHTML` in
    /// the `Recipe` data model itself (US-37 / CL-63 / AC-37.3) so cached
    /// articles render rich-body on re-open without needing a refresh.
    /// `onAppear()`'s `.article` case is unchanged by T-736.
    func refreshBlurbBlocks(forCanonicalURL url: URL) async {
        guard await dependencies.isOnline() else { return }
        guard let html = try? await dependencies.fetchHTML(for: url) else { return }
        let blurbHTML = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        guard !blurbHTML.isEmpty else { return }
        let parsed = ArticleHTMLParser.parse(html: blurbHTML)
        guard !parsed.isEmpty else { return }
        blurbBlocks = parsed
    }

    /// DUT-53: cache-hit ingredient self-heal. A recipe cached with empty
    /// `ingredients` but `hasDetail == true` (it has instructions) takes the
    /// `onAppear()` cache-hit fast path (`hydrateCachedRecipe`) and never
    /// re-parses — so a parser improvement (the DUT-42 WPRM-card fallback) or
    /// a site-content fix never reaches that already-cached row. When the
    /// displayed (cached) recipe has no ingredients, re-fetch + re-parse in
    /// the background; if the re-parse now recovers ingredients, persist them
    /// and swap them into the live recipe so they render in a later frame.
    ///
    /// Fire-and-forget, fail-silent, and non-downgrading — offline, fetch
    /// error, parse failure, or a still-empty re-parse all leave the cached
    /// view exactly as it was (never `.unavailable`). Same contract as
    /// ``refreshBlurbBlocks(forCanonicalURL:)`` (T-736 / REG-37): the cached
    /// view is already on screen, so a snackbar would misrepresent a working
    /// state, and holding `onAppear()` open on the fetch would serialize
    /// subsequent UI work behind a network call.
    ///
    /// Recipes whose cache has BOTH lists empty (`hasDetail == false`) never
    /// reach here — `onAppear()` routes them straight to `fetchAndParse()`,
    /// which already applies the DUT-42 fallback on every open. This closes
    /// the remaining gap for the has-instructions-but-no-ingredients shape.
    func backfillIngredientsIfEmpty() async {
        guard recipe?.ingredients.isEmpty == true else { return }
        guard await dependencies.isOnline() else { return }
        guard let html = try? await dependencies.fetchHTML(for: canonicalURL) else { return }
        guard
            let reparsed = try? dependencies.parseJSONLD(
                html: html,
                merging: listItem,
                canonicalURL: canonicalURL
            ),
            !reparsed.ingredients.isEmpty
        else { return }
        try? await dependencies.mergeDetail(reparsed)
        recipe = reparsed
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
