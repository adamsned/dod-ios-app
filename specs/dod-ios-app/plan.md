# Plan — Dutch Oven Daddy iOS App v1

**Status:** Phase 3 — Plan, draft for review
**Implements:** [`spec.md`](spec.md)
**Governed by:** [`../constitution.md`](../constitution.md)
**Clarifications:** [`clarifications.md`](clarifications.md)

This document translates the spec into a feasible architecture. Code that diverges from this plan needs a plan update first, not a quiet workaround.

---

## 0. Post-mix audit — resolves CL-10

Sampled the 30 most recent posts via WP REST. **1 of 30 (~3.3%)** is a non-recipe (the Dutch oven temperature chart article). That is below the 5% threshold CL-10 set for triggering an Article view.

**Decision:** v1 ships with no Article view. The hide-on-missing-JSON-LD logic from AC-1.7 absorbs non-recipe posts naturally. CL-10 is fully resolved; spec doesn't change.

If post-launch telemetry shows users disproportionately hitting the "Recipe unavailable" snackbar (AC-4.11), reopen this decision.

---

## 1. Architecture at a glance

**Modular Swift Package architecture.** A thin Xcode app target hosts a collection of Swift Package library modules. Each module is independently buildable, testable, and previewable. The compiler — not convention — enforces the layering. MV pattern with `@Observable` view models inside each Feature module.

### Repository layout

```
DODApp.xcodeproj                # Thin app shell only — @main, RootView, dependency wiring
  App/
    DODApp.swift                # @main entry
    RootView.swift              # TabView (iPhone) / NavigationSplitView (iPad)
    ContentTabs.swift           # Feed | Categories | Search | Saved
    AppDependencies.swift       # Composition root — wires modules together

Packages/
  DODDomain/                    # Pure value types. Zero dependencies.
    Sources/DODDomain/
      Recipe.swift
      RecipeListItem.swift
      Category.swift
      RecipeIngredient.swift
      RecipeInstruction.swift
      RecipeVideo.swift
      RecipeNutrition.swift
    Tests/DODDomainTests/

  DODSupport/                   # Tiny utilities. Zero dependencies.
    Sources/DODSupport/
      HTMLSanitizer.swift       # Strips WP HTML to plain text
      StringHasher.swift        # SHA256 for hashed search-query telemetry
      Logger.swift              # OSLog wrapper, redaction-safe
    Tests/DODSupportTests/

  DODDesignSystem/              # Visual primitives. Depends on nothing app-specific.
    Sources/DODDesignSystem/
      Colors.swift
      Typography.swift
      Spacing.swift
      Components/
        RecipeCard.swift
        EmptyState.swift
        OfflineBanner.swift
        LoadingSkeleton.swift
        Snackbar.swift
    Tests/DODDesignSystemTests/ # Snapshot tests live here

  DODAnalytics/                 # TelemetryDeck wrapper + event allowlist.
    Sources/DODAnalytics/
      Telemetry.swift
      AnalyticsEvent.swift      # Sealed enum — compiler-enforced allowlist
    Tests/DODAnalyticsTests/

  DODNetworking/                # Stateless. Returns Domain types or throws.
    Sources/DODNetworking/
      WPRestClient.swift        # WordPress REST endpoints
      RecipePageFetcher.swift   # Fetches rendered HTML page
      JSONLDRecipeParser.swift  # Extracts @type:Recipe from HTML
      ImageLoader.swift         # AsyncImage wrapper, disk cache
      NetworkMonitor.swift      # Connectivity for offline banner
      WPClientError.swift
    Tests/DODNetworkingTests/   # Golden-file JSON-LD tests live here

  DODPersistence/               # SwiftData. Owns LRU + saved-pin policy.
    Sources/DODPersistence/
      RecipeStore.swift
      CachedRecipe.swift
      CachedListPage.swift
      CachedImage.swift
      CachePolicy.swift
    Tests/DODPersistenceTests/  # In-memory ModelContainer tests

  DODFeatureFeed/               # One module per feature screen.
    Sources/DODFeatureFeed/
      FeedView.swift
      FeedViewModel.swift
      FeedRow.swift
    Tests/DODFeatureFeedTests/

  DODFeatureCategories/
    Sources/DODFeatureCategories/
      CategoryListView.swift
      CategoryListViewModel.swift
      CategoryRecipesView.swift
      CategoryRecipesViewModel.swift
    Tests/DODFeatureCategoriesTests/

  DODFeatureSearch/
    Sources/DODFeatureSearch/
      SearchView.swift
      SearchViewModel.swift
    Tests/DODFeatureSearchTests/

  DODFeatureRecipeDetail/
    Sources/DODFeatureRecipeDetail/
      RecipeDetailView.swift
      RecipeDetailViewModel.swift
      IngredientCheckRow.swift
      InstructionStep.swift
      RelatedRecipesStrip.swift
    Tests/DODFeatureRecipeDetailTests/

  DODFeatureSaved/
    Sources/DODFeatureSaved/
      SavedView.swift
      SavedViewModel.swift
    Tests/DODFeatureSavedTests/
```

### Module dependency graph

```
                            ┌────────────────┐
                            │   DOD App      │
                            │  (Xcode tgt)   │
                            └───────┬────────┘
              ┌─────────────┬───────┴───────┬─────────────┐
              ▼             ▼               ▼             ▼
   ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐
   │ FeatureFeed    │  │ FeatureCateg.  │  │ FeatureSearch │  │ FeatureRecipeDetail │
   └───────┬────────┘  └───────┬────────┘  └──────┬───────┘  └─────────┬──────────┘
           │                   │                  │                     │
           │           ┌───────┴──────────┐       │                     │
           ▼           ▼                  ▼       ▼                     ▼
   ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
   │ DODNetworking  │  │ DODPersistence │  │ DODDesignSys.  │  │ DODAnalytics   │
   └───────┬────────┘  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘
           │                   │                   │                   │
           └─────────┬─────────┘                   │                   │
                     ▼                             │                   │
              ┌─────────────┐                      │                   │
              │ DODDomain   │◄─────────────────────┘                   │
              └──────┬──────┘                                          │
                     │                                                 │
                     │     ┌─────────────┐                             │
                     └────►│ DODSupport  │◄────────────────────────────┘
                           └─────────────┘
```

Rules enforced by the compiler:
- **DODDomain** depends on nothing. (Pure value types.)
- **DODSupport** depends on nothing. (Stateless utilities.)
- **DODNetworking, DODPersistence** depend on `DODDomain` (+ `DODSupport`). They do **not** import each other.
- **DODDesignSystem, DODAnalytics** depend on nothing app-specific. (Designer/owner could lift them into other apps unchanged.)
- **DODFeature\***: each depends on `Domain`, `Networking`, `Persistence`, `DesignSystem`, `Analytics`, `Support`. **No Feature imports another Feature.** Cross-feature navigation is brokered by the app target.
- **DODApp** (Xcode target) is the only place modules are wired together. Composition root pattern.

### Why this layout

- **Compiler-enforced layering** replaces convention. A `DODDomain` file literally cannot `import DODNetworking` — build fails.
- **Parallel-safe PRs.** Two feature tasks rarely touch the same files. Merge conflicts become rare.
- **Independent previews and tests.** Open `DODFeatureFeed/Package.swift` in Xcode and iterate without compiling the rest of the app.
- **Drop-in replaceability.** Rewriting `DODFeatureSearch` (e.g. to add ingredient-body search in v2) doesn't ripple.
- **Feature flag = swap a module.** Want to ship without Saved in an emergency? Stop linking `DODFeatureSaved` in `DODApp`.

---

## 2. Data models

### Domain (pure value types)

```swift
struct Recipe: Sendable, Hashable, Identifiable {
    let id: Int                        // WP post id
    let slug: String
    let title: String
    let excerpt: String                // sanitized plain text
    let canonicalURL: URL              // post.link, used for share
    let heroImage: URL?
    let heroImageLargeURL: URL?        // up to 2048px for iPad
    let categoryIDs: [Int]
    let publishedAt: Date

    // Detail-only — populated after JSON-LD parse:
    let ingredients: [RecipeIngredient]
    let instructions: [RecipeInstruction]
    let prepTime: Duration?
    let cookTime: Duration?
    let totalTime: Duration?
    let servings: Int?
    let nutrition: RecipeNutrition?
    let video: RecipeVideo?
}

struct RecipeListItem: Sendable, Hashable, Identifiable {
    let id: Int                        // WP post id
    let title: String
    let excerpt: String
    let heroImage: URL?
    let publishedAt: Date
    let totalTimeDisplay: String?      // "30 min" if known from REST (may be nil pre-detail-fetch)
}

struct Category: Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let count: Int
}

struct RecipeIngredient: Sendable, Hashable, Identifiable {
    let id: UUID                       // local — JSON-LD has no ID
    let text: String                   // raw JSON-LD recipeIngredient line
}

struct RecipeInstruction: Sendable, Hashable, Identifiable {
    let id: UUID
    let step: Int                      // 1-based
    let text: String
}

struct RecipeVideo: Sendable, Hashable {
    let url: URL
    let thumbnailURL: URL?
    let duration: Duration?
}

struct RecipeNutrition: Sendable, Hashable {
    let calories: String?
    let servingSize: String?
    let proteinGrams: String?
    let carbsGrams: String?
    let fatGrams: String?
    // String, not Double — JSON-LD nutrition values are unitful strings ("12g", "200 kcal").
}
```

### Persistence (SwiftData `@Model`)

```swift
@Model final class CachedRecipe {
    @Attribute(.unique) var id: Int
    var slug: String
    var title: String
    var excerptText: String
    var canonicalURLString: String
    var heroImageURLString: String?
    var heroImageLargeURLString: String?
    var categoryIDs: [Int]
    var publishedAt: Date
    var lastViewedAt: Date              // drives LRU
    var isSaved: Bool                   // pins from eviction
    var jsonLDParsedAt: Date?           // nil = detail never fetched
    var jsonLDFailedAt: Date?           // non-nil = blocklist for AC-1.7
    var ingredientsJSON: Data?          // encoded [RecipeIngredient]
    var instructionsJSON: Data?
    var nutritionJSON: Data?
    var videoJSON: Data?
    var prepSeconds: Int?
    var cookSeconds: Int?
    var totalSeconds: Int?
    var servings: Int?
}

@Model final class CachedListPage {
    @Attribute(.unique) var key: String    // "home" | "category:<id>" | "search:<hash>"
    var pageNumber: Int                    // last page fetched
    var recipeIDs: [Int]                   // ordered
    var fetchedAt: Date
}

@Model final class CachedImage {
    @Attribute(.unique) var urlString: String
    var bytes: Data
    var fetchedAt: Date
    var lastUsedAt: Date
    var pinnedToSavedRecipeID: Int?        // non-nil = excluded from LRU eviction
}
```

### Cache policies

- **LRU window:** 100 unsaved `CachedRecipe` rows. On insert, evict by oldest `lastViewedAt` until size ≤ 100. Saved recipes (`isSaved == true`) never evict (NFR-1).
- **Image cache:** capped at 200 MB total `bytes` size, evict oldest `lastUsedAt` first, skip rows with `pinnedToSavedRecipeID != nil` (NFR-2).
- **Blocklist for AC-1.7:** a `CachedRecipe` row with `jsonLDFailedAt != nil` is filtered out of all list rendering. Pull-to-refresh clears `jsonLDFailedAt` on matching rows so newly-fixed posts can return.

---

## 3. Networking

### WP REST endpoints used

| Purpose | Endpoint | Notes |
|---|---|---|
| Home feed | `GET /wp-json/wp/v2/posts?per_page=20&page=N&_fields=id,slug,link,title,excerpt,date,featured_media,categories` | Newest first by default |
| Category list | `GET /wp-json/wp/v2/categories?per_page=100&hide_empty=true` | All categories, alpha-sort client-side |
| Category recipes | `GET /wp-json/wp/v2/posts?categories=<id>&per_page=20&page=N&_fields=...` | Same `_fields` as feed |
| Search | `GET /wp-json/wp/v2/posts?search=<q>&per_page=20&_fields=...` | WP matches title + excerpt + content by default |
| Featured image | `GET /wp-json/wp/v2/media/<id>?_fields=source_url,media_details` | Pick size from `media_details.sizes` per CL-6 |

All requests share a 30s timeout. Failures throw a typed `WPClientError` that the view models convert to user-friendly empty/error states per CC-4.

### Recipe detail fetch — the two-step

1. Fetch `post.link` via `RecipePageFetcher`. Returns raw HTML.
2. `JSONLDRecipeParser.parse(html:)` finds every `<script type="application/ld+json">` block, JSON-decodes each, picks the entry with `@type == "Recipe"` (or `@graph` containing one), and maps to `Recipe`.
3. On success: persist into `CachedRecipe`, set `jsonLDParsedAt = now`, return the populated `Recipe`.
4. On failure: persist `jsonLDFailedAt = now` so the post drops out of lists per AC-1.7. View pops back with the snackbar.

### Image loading

`ImageLoader` is a small actor wrapping `URLSession.shared` + the `CachedImage` SwiftData store. Resolution choices:
- List rows: request `medium_large` size (~768px) from `media_details.sizes`.
- Detail hero: request the largest size ≤ 2048px.
- When saving a recipe (US-5): pre-download both list and large sizes for offline.

### JSON-LD parser — implementation note

Use Swift's `Regex` + a small streaming search over the HTML — *not* a full HTML parser. The `<script type="application/ld+json">…</script>` regex is reliable for WPRM's output. Decode the inner string with `JSONSerialization` (faster than `Codable` for unknown-shape JSON). Then walk the object looking for `@type == "Recipe"`. **Do not** add SwiftSoup or a CSS-selector library — constitution §3 default-no on new dependencies.

---

## 4. Feature plan, screen by screen

### Feed (US-1)
- `FeedViewModel` owns `[RecipeListItem]`, a paging cursor, loading state, and a `Bool isOffline`.
- Pull-to-refresh resets cursor and calls `WPRestClient.posts(page: 1)`.
- Bottom-trigger infinite scroll uses `task(id:)` on a sentinel row.
- Offline path: hydrate from `CachedListPage(key: "home")` and show the offline banner.

### Categories (US-2)
- `CategoryListView` fetches `/categories` once, alpha-sorts, hides `count == 0`.
- Tapping pushes `CategoryRecipesView` with the same row component as Feed.

### Search (US-3)
- `SearchView` debounces input 300ms via `.task(id: query)` + `Task.sleep`.
- Telemetry sends `recipe_searched` with `query_hash` (SHA256 of lowercased query), never raw.
- Empty state strings as in AC-3.4 / AC-3.7.

### Recipe Detail (US-4)
- Loads `RecipeListItem` from cache instantly (for hero + title), then triggers the two-step detail fetch.
- While fetching: skeleton placeholders for ingredients/instructions per CC-3.
- Bookmark toggle is a single SwiftUI animation, calls `RecipeStore.toggleSaved(id:)`. (CL-38 / T-380 swapped the original heart glyph to `bookmark` to match the Saved tab — see AC-4.7's amended wording.)
- On failure: snackbar + nav pop per AC-4.11.

### Saved (US-5)
- Pure SwiftData query: `CachedRecipe` where `isSaved == true`, sorted by `lastViewedAt`-or-save-time desc.
- Save action triggers a background pre-download of hero images (large + list size) and persists the full `Recipe` payload.

---

## 5. DesignSystem & brand tokens

Palette sampled from dutchovendaddy.com hero imagery (cast-iron + warm earth). **These are starting tokens** — the designer/owner can tune at the Phase 5 polish step without changing semantics.

```swift
enum DODColor {
    // Brand
    static let castIronBrown   = Color(hex: 0x3D2B1F)   // primary nav, headings
    static let burntOrange     = Color(hex: 0xC56A24)   // accent, save bookmark, buttons
    static let warmGold        = Color(hex: 0xD4A24C)   // secondary accent
    static let cream           = Color(hex: 0xFAF6EE)   // app background light
    static let charcoal        = Color(hex: 0x2C2C2C)   // body text light
    static let darkEarth       = Color(hex: 0x1B140E)   // app background dark
    static let creamSubtle     = Color(hex: 0xE6DECF)   // body text dark

    // Semantic
    static let surface         = Color("Surface")        // asset catalog, light/dark variants
    static let surfaceElevated = Color("SurfaceElevated")
    static let label           = Color("Label")
    static let labelSecondary  = Color("LabelSecondary")
    static let accent          = Color("Accent")         // = burntOrange
}
```

Typography ramp (system fonts, respects Dynamic Type via `.font(.system(...))` and `.dynamicTypeSize(...)`-aware variants):

| Token | Style |
|---|---|
| `displayLarge` | `largeTitle`, semibold |
| `displayMedium` | `title2`, semibold |
| `heading` | `headline` |
| `body` | `body` |
| `bodyEmphasized` | `body`, semibold |
| `caption` | `caption` |

All component padding uses 4pt increments; the grid is `4 / 8 / 12 / 16 / 24 / 32`.

Components needed for v1: `RecipeCard`, `EmptyState`, `OfflineBanner`, `LoadingSkeleton`, `Snackbar`. Each gets its own snapshot tests (light/dark × iPhone/iPad) per constitution §6.

---

## 6. Dependencies

Constitution default = "no new dependency." v1 needs exactly **one** non-Apple SPM package:

| Package | Purpose | Justification | Imported by |
|---|---|---|---|
| `TelemetryDeck/SwiftSDK` | Analytics | Required by constitution §9. No alternative. | `DODAnalytics` only |

`TelemetryDeck` is imported **only inside `DODAnalytics`**. No Feature module imports it directly — they call `DODAnalytics`'s wrapper. This means the analytics provider can be swapped without touching feature code.

Everything else is Apple framework: SwiftUI, Observation, SwiftData, URLSession, OSLog, MetricKit, AVKit (for video).

---

## 7. Testing strategy (constitution §6 enforcement)

| AC range | Test type | Where |
|---|---|---|
| AC-1.* | Swift Testing unit tests on `FeedViewModel` + mock `WPRestClient` | `FeedViewModelTests.swift` |
| AC-2.* | Swift Testing on `CategoryListViewModel`, `CategoryRecipesViewModel` | per-feature folders |
| AC-3.* | Swift Testing on `SearchViewModel` with debounce + hashing assertions | `SearchViewModelTests.swift` |
| AC-4.* | Swift Testing on `RecipeDetailViewModel` + `JSONLDRecipeParser` golden-file tests | parser tests use checked-in HTML fixtures |
| AC-5.* | Swift Testing on `RecipeStore`, in-memory SwiftData store | `RecipeStoreTests.swift` |
| AC-6.* | Swift Testing on the share-button view model action | `RecipeDetailViewModelTests.swift` |
| CC-1 (a11y) | Snapshot tests with `AccessibilityElement` assertions | DesignSystem snapshot suite |
| CC-2/3/4 | UI tests on offline/loading/error states | `DODUITests/StatesUITests.swift` |
| CC-7 (perf) | XCTest performance tests on cold launch + list scroll, run only in CI | `DODPerformanceTests/` |
| CC-8 (iPad) | Snapshot tests at iPad 12.9" portrait+landscape | DesignSystem snapshot suite |

JSON-LD parser gets **golden-file tests** — checked-in HTML samples from 5 representative posts (cake, savory, soup, bread, the temperature-chart non-recipe). Parser must return populated `Recipe` for 4 and a typed failure for 1.

---

## 8. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-1 | WPRM updates change JSON-LD shape | Medium | High — recipes stop parsing | Defensive parser with per-field fallbacks; CI runs the golden-file tests against a small live sample weekly via a scheduled GitHub Action |
| R-2 | Blog HTML page size grows, recipe detail fetch slow | Medium | Medium — AC-4 perf budget at risk | Compress on the wire (`Accept-Encoding: gzip`); add a request-coalescing layer so re-opens hit cache |
| R-3 | App Store reviewer flags TelemetryDeck despite no ATT | Low | Medium | App Privacy answer is honest (Usage Data, not linked, not tracking); have a v0.9 TestFlight build with telemetry **toggle-off** ready in case |
| R-4 | Some posts have multi-language `recipeInstructions` shapes (HowToStep array vs plain string array) | High | Medium | Parser handles both shapes from day one; golden-file fixtures include both |
| R-5 | SwiftData migration on a future schema change | Medium | High — saved recipes could be lost | Versioned schema from v1; never delete `CachedRecipe` fields, only add — migration plan template in repo |
| R-6 | iPad split-view layouts add complexity not budgeted | Medium | Medium | iPad layouts are Phase 4 tasks tagged `[ipad]` — can defer the last two if schedule slips, file an issue, do not silently merge |
| R-7 | Composite gesture pitfalls in `LazyVGrid` + `ScrollView` + `Button` | Medium | High — feed becomes un-scrollable | iOS gesture disambiguation between scroll-pan and tap is fragile when a `Button` dominates a tall cell. Use the `recipeCardTap` modifier (or equivalent `.contentShape` + `.onTapGesture` + `isButton` trait pattern) for any future row-style component; never wrap a tall card in a `Button` without proving scroll still works (see REG-DOD-LIST-SCROLL) |
| R-8 | Code-generation tools silently clobbering hand-maintained config | High | High — survival-critical Info.plist keys lost on next regenerate | Anything in `App/Info.plist` (and similar plist/xcconfig files) not also expressed in `project.yml` is lost on the next `xcodegen generate`. Keep survival-critical keys in `project.yml`'s `info.properties` block. Reviewer rule: any PR that hand-edits `App/Info.plist` is suspicious — push the value back to `project.yml` instead (see REG-INFO-PLIST-CLOBBER) |

---

## 9. Rollout

1. **Internal builds via Xcode Cloud** — every merge to `main` produces an .ipa.
2. **TestFlight closed beta** — 10 testers (owner + family/friends), 2-week soak before App Store submission.
3. **TestFlight public beta** — only if needed for crash data; otherwise skip.
4. **App Store v1.0** — submit when:
   - All ACs map to passing tests.
   - All risk register items have mitigations either shipped or explicitly accepted.
   - Performance budgets met on iPhone 13 baseline device.
   - App Privacy questionnaire reviewed against §9 of constitution.

---

## 10. Definition of Done — v1.0

- [ ] Every AC in `spec.md` maps to a named, passing test.
- [ ] All risk register items have a mitigation status (Shipped / Accepted / Deferred-with-issue).
- [ ] Cold launch on iPhone 13: < 1.5s (perf test passes in CI).
- [ ] Snapshot tests pass for every DesignSystem component and top-level Feature view in light + dark, iPhone + iPad.
- [ ] App Privacy questionnaire matches §9 word-for-word.
- [ ] App icon + screenshots prepared per NFR-4.
- [ ] Owner approval on TestFlight build.

---

## Phase 6 work cluster — Consultant pass

Added 2026-05-23 by the consultant-pass amendment (clarifications CL-16, CL-17, CL-18). Six high-level tasks listed here so the plan stays the source of truth; per-task scope/files/AC/deps/estimate live in `tasks.md` under "Phase 6 — Consultant pass".

- **T-300 — Card visual density.** Implements CC-9: 2-column grid on compact horizontal size class (iPhone portrait), 3-column on regular (iPad, large iPhones in landscape), across Feed / Categories / Search / Saved. Shorter RecipeCard hero so ≥3 rows are visible above the fold on iPhone 13 baseline. Touches `Packages/DODFeatureFeed`, `Packages/DODFeatureCategories`, `Packages/DODFeatureSearch`, `Packages/DODFeatureSaved`, and `Packages/DODDesignSystem/Components/RecipeCard.swift`. Snapshot tests at iPhone 13 + iPad 12.9" lock the new layout. Supersedes the one-column-compact assumption in T-150.
- **T-301 — App icon placeholder + asset catalog.** Promote the placeholder app icon into a real `AppIcon.appiconset` with every required size populated (1024 marketing, all iPhone/iPad scaled variants). Asset catalog only — does not change app launch behavior. Unblocks the TestFlight build that's currently flagged "missing icon" in App Store Connect. Closes the part of T-180 that was deferred behind owner-provided artwork.
- **T-302 — Recipe detail polish.** Two visual fixes the consultant flagged on recipe detail (US-4): (a) sticky save + share buttons that stay reachable when scrolled to instructions/related, and (b) a hero overlay (title + meta row over a gradient at the bottom of the hero image) so the meta row is anchored at the top of the visible content area instead of dropping below the fold. No new ACs — refinement of AC-4.1, AC-4.7, AC-4.8 within the existing contract.
- **T-303 — Onboarding sheet (US-8).** Implements US-8 AC-8.1, AC-8.2, AC-8.3. New `OnboardingSheet` view in `Packages/DODFeatureFeed` (or a small new `DODFeatureOnboarding` module if it grows beyond one file — decide during the task). Wires the `dod.onboardingCompletedV1` UserDefaults flag in the composition root (`App/AppDependencies.swift` or a small helper). Snapshot tests at iPhone + iPad. Unit test asserts the flag is set after dismiss and the sheet is not shown on second launch.
- **T-304 — Cook Mode (US-7).** Implements US-7 AC-7.1 through AC-7.6. New `CookModeView` + `CookModeViewModel` in `Packages/DODFeatureRecipeDetail`. "Cook Now" CTA added to `RecipeDetailView`. View model owns the shared ingredient-check state binding (AC-7.5) — likely lifted up from `RecipeDetailViewModel` into a small `IngredientCheckState` value shared via environment or initializer injection. UIKit `UIApplication.shared.isIdleTimerDisabled` toggle wrapped in a small `IdleTimerCoordinator` so it's mockable in tests (AC-7.3). Swipe + tap navigation. Snapshot tests at iPhone + iPad, light + dark. UI smoke test (L3) launches Cook Mode and verifies the screen does not auto-lock during a 10-second hold.
- **T-305 — Cook Mode telemetry event.** Adds `cookModeStarted(recipeID: Int)` case to the `AnalyticsEvent` sealed enum in `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift`. Wires the send-site inside `CookModeViewModel` on first entry per recipe-per-session (AC-7.7). Unit test asserts the event fires exactly once per recipe even if the user re-enters Cook Mode after exiting. Companion test asserts no raw text is included in the payload (only the integer ID). The constitution §9 allowlist was amended in the consultant pass to permit this event; this task lands the code.

Dependencies: T-300, T-301, T-302, T-303 are parallel-safe. T-305 depends on T-304. T-304 depends on T-302 only to avoid merge churn on `RecipeDetailView`; functionally they're independent.

---

## 11. Out of plan — explicit

These are *not* in this plan and require a plan update before any code is written for them:

- Article view for non-recipe posts (CL-10 said no for v1).
- iCloud / CloudKit sync (deferred to v2).
- In-app cooking timers (the consultant pass brought Cook Mode's screen-awake half in scope per US-7; per-step countdown timers remain out for v1).
- Shopping list (out of spec).
- Watch / Mac / Vision targets (constitution §2).
- Any analytics SDK besides TelemetryDeck (constitution §9).

---

## Open items for Phase 4 — Tasks

Phase 4 will decompose this plan into single-PR tasks (1–4 hours each). With the modular split, the work organizes naturally **per module**, which is also the PR boundary. Most modules can be developed in parallel once their dependencies exist.

Notional groupings, in approximate dependency order:

1. **Repo + app shell scaffolding** — Xcode project, app target, CI (Xcode Cloud or GH Actions), SwiftLint, swift-format, README. Empty `DODApp` that builds and launches to a black screen.
2. **DODDomain module** — value types, Sendable/Hashable conformances, tests. Foundational; everything blocks on this.
3. **DODSupport module** — sanitizer, hasher, logger. Independent, can run parallel to Domain.
4. **DODDesignSystem module** — palette, typography, spacing, the 5 components, snapshot test infrastructure. Parallel after step 1.
5. **DODAnalytics module** — TelemetryDeck wrapper, sealed `AnalyticsEvent` enum. Parallel after step 1.
6. **DODNetworking module** — `WPRestClient`, `RecipePageFetcher`, `JSONLDRecipeParser` + golden-file fixtures, `ImageLoader`, `NetworkMonitor`. Blocked on Domain.
7. **DODPersistence module** — `CachedRecipe`/`CachedListPage`/`CachedImage` `@Model`s, `RecipeStore`, LRU + saved-pin policy. Blocked on Domain.
8. **DODFeatureFeed module** — Feed screen, view model, row, tests. Blocked on Networking + Persistence + DesignSystem.
9. **DODFeatureCategories module** — list + detail screens. Parallel to Feed once dependencies land.
10. **DODFeatureSearch module** — search screen + hashed-telemetry. Parallel to Feed.
11. **DODFeatureRecipeDetail module** — largest. Skeleton view, ingredients, instructions, video, related, save toggle. Split across 4–6 PRs.
12. **DODFeatureSaved module** — saved tab + offline pre-download. Blocked on Detail (shares the same `RecipeDetailView`).
13. **App composition** — wire modules into `DODApp`, `RootView`, iPhone/iPad navigation, tab bar, deep-link plumbing for share-back-into-app (low priority for v1).
14. **iPad adaptation pass** — `NavigationSplitView`, size-class-aware layouts in every feature.
15. **Accessibility audit pass** — Dynamic Type AX5 sweep, VoiceOver labels, contrast in light/dark.
16. **Performance pass** — cold-launch trace, list-scroll instrument, set up CI perf gates.
17. **Release prep** — App icon, screenshots, App Privacy questionnaire, marketing copy, TestFlight setup.

Steps 2–5 can be developed in parallel by different agents/contributors. Steps 8–12 can be developed in parallel once 6 and 7 land. This is the modular-development payoff.
