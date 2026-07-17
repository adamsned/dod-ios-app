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
            // DUT-202: if a usable cached recipe is already on screen (the
            // reclassify path set it), keep it rather than discarding a good view
            // + auto-popping on a transient (non-offline) failure.
            if let recipe, !recipe.ingredients.isEmpty {
                loadState = .ready
            } else {
                // DUT-627: the FETCH threw — we never saw the page, so we can't
                // know the post is genuinely missing (that's the JSON-LD-failed
                // `.unavailable` branch in `apply(classification:)`, which only
                // runs after a successful fetch). Treat a no-cache fetch failure
                // as RETRYABLE: keep the user on a retry surface instead of
                // downgrading to `.unavailable` + auto-pop on a flaky connection.
                loadState = .retryableError
                snackbarMessage = "Couldn't load recipe — check your connection."
            }
            return
        }

        // DUT-577: run the full classify/parse pipeline (JSON-LD parse,
        // recipe-subject detection, WPRM-card recovery, article-body
        // extraction, blurb extraction + parse) OFF the main actor so the
        // main thread isn't blocked scanning a several-hundred-KB round-up
        // page before `loadState` flips. The pure result is a `PageClassification`
        // value; the main-actor code below only sets `@Observable` state and
        // awaits the async persistence/related-load seams. Classification is
        // identical to the pre-DUT-577 inline decision tree (DUT-544/554/555),
        // and `hasRecipeJSONLD` is scanned exactly ONCE (the old code re-scanned
        // it at the article-classify entry — deduped here). DUT-582's blurb
        // body-image base-URL threading lives inside `classifyPage(html:)`.
        let classification = await classifyPage(html: html)
        await apply(classification: classification, html: html)
    }

    /// DUT-627 — retry the fetch after a transient `.retryableError`. Resets to
    /// the loading skeleton and re-runs the fetch/parse pipeline; a now-reachable
    /// network resolves to `.ready` / `.article`, a confirmed-missing post to
    /// `.unavailable`, and a still-flaky connection back to `.retryableError`.
    /// Wired to the Retry button the view shows in the `.retryableError` state.
    public func retryLoad() async {
        loadState = .loadingDetail
        snackbarMessage = nil
        await fetchAndParse()
    }

    /// DUT-577 — `@MainActor` apply step: consume the off-main
    /// ``PageClassification`` and set `@Observable` state + await the async
    /// persistence / related-strip seams. Behavior/ordering matches the
    /// pre-DUT-577 inline flow.
    func apply(classification: PageClassification, html: String) async {
        switch classification {
        case .recipe(let parsed, let blurbBlocks):
            try? await dependencies.mergeDetail(parsed)
            recipe = parsed
            self.blurbBlocks = blurbBlocks
            loadState = .ready
            await loadRelated(forCategoryID: parsed.categoryIDs.first)
        case .cardRecipe(let cardRecipe):
            try? await dependencies.mergeDetail(cardRecipe)
            recipe = cardRecipe
            loadState = .ready
            await loadRelated(forCategoryID: cardRecipe.categoryIDs.first)
        case .article(let article):
            // Persist so subsequent opens hit the cache path. `mergeDetail` on an
            // article-kind recipe stamps `jsonLDFailedAt = .now` (CL-63 decision 7).
            try? await dependencies.mergeDetail(article)
            recipe = article
            loadState = .article(article)
        case .unavailable:
            try? await dependencies.markJSONLDFailed(id: listItem.id)
            loadState = .unavailable
            snackbarMessage = "Recipe unavailable."
        }
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
            // DUT-202: show the usable cached recipe (ingredients + blurb) right
            // away, then attempt the re-classify. A transient (non-offline) fetch
            // failure must keep this view, not downgrade it to "Recipe unavailable"
            // + auto-pop (see the fetch catch in fetchAndParse).
            recipe = cached
            loadState = .ready
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
        Task { [weak self] in
            await self?.hydrateBlurbAndIngredients()
        }
    }

    /// DUT-581 — the cache-hit background hydrate: fetch the canonical HTML
    /// ONCE and pass it into BOTH the blurb refresh and the ingredient
    /// backfill. Pre-DUT-581 each helper fetched its own copy, so a cache-hit
    /// with instructions-present-but-empty-ingredients (DUT-53 shape) fired
    /// two back-to-back GETs of the identical URL. Gating (online) + fail-silent
    /// semantics are unchanged: offline skips the fetch entirely (no network
    /// call, no state change), a transient fetch error is swallowed (`try?`),
    /// and neither helper ever surfaces a snackbar or downgrades the load state.
    func hydrateBlurbAndIngredients() async {
        guard await dependencies.isOnline() else { return }
        guard let html = try? await dependencies.fetchHTML(for: canonicalURL) else { return }
        await refreshBlurbBlocks(html: html)
        // DUT-53: self-heal a cached recipe whose ingredients are empty —
        // parsed before the DUT-42 WPRM fallback existed, or fixed on the site
        // since it was cached. No-op when ingredients are already present.
        await backfillIngredientsIfEmpty(html: html)
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
    ///    `ArticleHTMLParser.parse` pipeline `fetchAndParse()` uses.
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
    /// DUT-581 — the HTML is fetched ONCE by ``hydrateBlurbAndIngredients()``
    /// and passed in (the online-gate + fetch moved to that coordinator so the
    /// blurb refresh + ingredient backfill share a single GET). DUT-577 — the
    /// pure `extractRecipeBlurb` + `parse` scan runs OFF the main actor; only
    /// the `blurbBlocks` assignment stays on the main actor.
    ///
    /// **Not called for articles.** Articles persist `articleBodyHTML` in
    /// the `Recipe` data model itself (US-37 / CL-63 / AC-37.3) so cached
    /// articles render rich-body on re-open without needing a refresh.
    /// `onAppear()`'s `.article` case is unchanged by T-736.
    func refreshBlurbBlocks(html: String) async {
        // DUT-582: thread the page's canonical URL into the off-main parse so
        // protocol-/root-relative body-image sources resolve to absolute
        // http(s) URLs on the cache-hit refresh path too (matches `fetchAndParse`).
        let parsed = await Self.parseBlurbBlocks(html: html, baseURL: canonicalURL)
        guard !parsed.isEmpty else { return }
        blurbBlocks = parsed
    }

    /// DUT-577 — the pure blurb extract + parse, run off the main actor. Static +
    /// Sendable so it hops onto a detached task; the `@MainActor` caller only
    /// assigns the returned blocks. Empty result when the extract is empty (same
    /// contract as the inline pre-DUT-577 code). DUT-582 — `baseURL` is threaded
    /// into `ArticleHTMLParser.parse` so protocol-/root-relative body-image
    /// sources resolve to absolute http(s) URLs.
    nonisolated static func parseBlurbBlocks(html: String, baseURL: URL) async -> [ArticleBlock] {
        await Task.detached(priority: .userInitiated) {
            let blurbHTML = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: .max)
            return blurbHTML.isEmpty ? [] : ArticleHTMLParser.parse(html: blurbHTML, baseURL: baseURL)
        }.value
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
    ///
    /// DUT-581 — the HTML is fetched ONCE by ``hydrateBlurbAndIngredients()`` and
    /// passed in (no second GET of the same URL). The empty-ingredients guard
    /// runs first so a recipe that already HAS ingredients short-circuits without
    /// touching the passed HTML. DUT-577 — the pure `parseJSONLD` re-scan runs
    /// off the main actor; only `mergeDetail` + the `recipe` assignment are on
    /// the main actor.
    func backfillIngredientsIfEmpty(html: String) async {
        guard recipe?.ingredients.isEmpty == true else { return }
        let dependencies = self.dependencies
        let listItem = self.listItem
        let canonicalURL = self.canonicalURL
        let reparsed = await Task.detached(priority: .userInitiated) {
            try? dependencies.parseJSONLD(
                html: html,
                merging: listItem,
                canonicalURL: canonicalURL
            )
        }.value
        guard let reparsed, !reparsed.ingredients.isEmpty else { return }
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
        // Filter the current recipe out FIRST, then cap to 4 — so a self-match
        // (this recipe appearing in its own category's listing) doesn't burn
        // one of the 4 shown slots. `relatedRecipes` deliberately over-fetches
        // by one for exactly this reason.
        related = Array((fetched ?? []).filter { $0.id != listItem.id }.prefix(4))
    }
}
