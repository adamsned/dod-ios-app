import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// Article-rendering screen for posts that lack parseable JSON-LD `@type: Recipe`
/// data — typically roundup posts like "Best Dutch Oven Recipes (30+ Tried and
/// Tested Favorites)" that the user wants to read in-app without the post
/// being hidden from lists per the pre-T-640 CL-9 contract.
///
/// **What `ArticleDetailView` shows (US-37 / AC-37.3 + DOD-ART-1):**
/// - Hero image (`RecipeDetailHero`, same primitive the recipe screen uses).
/// - Title + published date caption.
/// - The article body rendered as **native blocks** — styled headings, photos
///   with captions, bulleted/numbered lists, and paragraphs with tappable
///   links + bold/italic — parsed from the stored body HTML by
///   ``DODSupport/ArticleHTMLParser``. This replaces the v1 plain-text wall
///   that collapsed a 30+ recipe round-up (44 photos / 90 links) into one
///   unreadable blob (CL-63 "plain text for v1" → DOD-ART-1 rich follow-up).
///
/// **Legacy / fallback path.** Articles cached before DOD-ART-1 stored stripped
/// plain text (no tags), and a malformed body parses to zero blocks; either
/// way the view falls back to a single plain-text `Text` so nothing renders
/// blank. The body re-fetches as HTML on the next online open.
///
/// **What `ArticleDetailView` deliberately does NOT show (CL-63 decision 5):**
/// Ingredients, Cook Mode CTA, servings stepper, ratings, comments, related
/// strip — articles carry none of the `Recipe` data those need. Save + Share
/// inherit from the parent `RecipeDetailView` toolbar (AC-4.7 + AC-4.8).
///
/// Spec trace: US-37, CL-63, AC-37.3, AC-37.5, AC-37.6, DOD-ART-1, CC-1.
struct ArticleDetailView: View {

    let recipe: Recipe

    /// T-806 — caps the article body to a centered reading column on iPad
    /// (`.regular`); iPhone (`.compact`) is byte-identical (the modifier
    /// returns the content unchanged), so the L4 article snapshots don't move.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Parsed once per view identity (synchronously in `init`) so the first
    /// frame is already rich — no plain-text-then-rich flash — and snapshot
    /// rendering is deterministic. An 87 KB round-up parses in single-digit
    /// milliseconds, so the one-time cost on article open is invisible.
    @State private var blocks: [ArticleBlock]

    init(recipe: Recipe) {
        self.recipe = recipe
        _blocks = State(initialValue: ArticleHTMLParser.parse(html: recipe.articleBodyHTML ?? ""))
    }

    var body: some View {
        // DUT-572 / CL-312 — `RecipeDetailHero` now ignores the top safe area
        // (full-bleed) and reads its `topInset` from the parent. Read the real
        // inset here and pass it in so the article hero renders identically.
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    RecipeDetailHero(
                        url: recipe.heroImageLargeURL ?? recipe.heroImage,
                        title: recipe.title,
                        topInset: topInset
                    )

                    VStack(alignment: .leading, spacing: DODSpacing.md) {
                        publishedDateCaption
                        articleBody
                    }
                    .padding(.horizontal, DODSpacing.md)
                    .padding(.bottom, DODSpacing.xl)
                    .readableContentColumn(horizontalSizeClass)
                }
            }
            .coordinateSpace(name: "recipeScroll")
            // DUT-672 — same immersive header as the recipe hero (DUT-638): let
            // the scroll content run to the very top so the article photo sits
            // UNDER the toolbar (the blur strip is the header), instead of the
            // GeometryReader keeping the ScrollView below the safe-area top and
            // the brown `DODColor.surface` background showing as a header band.
            // The parent GeometryReader still reports the real `topInset`.
            .ignoresSafeArea(.container, edges: .top)
        }
        .background(DODColor.surface)
    }

    /// "Published <absolute date>" caption above the body — the shared
    /// ``PublishedDateCaption`` ("Published June 1, 2026", long style). DUT-95 /
    /// T-788 first replaced the relative "Published X ago"; T-789 / CL-185
    /// (DUT-96) moved it to the shared long-style component the recipe detail
    /// also uses (medium → long per Ned). The visible text equals the VoiceOver
    /// label by construction, so no separate `.accessibilityLabel` is needed.
    private var publishedDateCaption: some View {
        PublishedDateCaption(date: recipe.publishedAt)
    }

    /// The rendered article body: native blocks when the HTML parsed, else a
    /// single plain-text fallback (legacy cache / unparseable body).
    ///
    /// T-732 / CL-129: the non-empty-blocks branch now delegates to the shared
    /// ``ArticleBlocksView`` so the recipe-detail expanded blurb (AC-4.12) and
    /// articles share a single source of truth for per-block styling. Render
    /// tree + per-block fonts/colors/spacing are byte-identical to the
    /// pre-T-732 inline `VStack { ForEach { blockView(...) } }` so the L4
    /// `ArticleDetailViewSnapshotTests` baselines are unaffected.
    @ViewBuilder
    private var articleBody: some View {
        if blocks.isEmpty {
            // Parser found no blocks — a legacy plain-text cache row, or an
            // article whose body uses only shapes the block scan doesn't emit
            // (a bare <table>, an <iframe> embed, etc.). `articleBodyHTML` now
            // holds raw HTML, so strip it to readable text rather than dumping
            // literal `<table>`/`<p>` tags on screen. No accessibilityLabel
            // override here — the Text content IS the body, so VoiceOver should
            // read it, not a generic "Article body". (review DOD-ART-1)
            let fallback = HTMLSanitizer.plainText(from: recipe.articleBodyHTML ?? "")
            if !fallback.isEmpty {
                Text(fallback)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else {
            ArticleBlocksView(blocks: blocks)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Article body")
        }
    }
}
