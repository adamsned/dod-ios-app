# Tasks — Dutch Oven Daddy iOS App v1

**Status:** Phase 4 — Tasks, draft for review
**Implements:** [`plan.md`](plan.md)
**Realizes:** [`spec.md`](spec.md)

Each task is a single PR, 1–4 hours of focused work. Field meanings:

- **Scope** — what the PR does, in one or two sentences. If it grows beyond this, split it.
- **Files** — files likely touched. Not exhaustive; new helpers are fine, sweeping unrelated edits are not.
- **AC** — acceptance: the test or verification that proves the task is done. References `spec.md` AC IDs when applicable.
- **Deps** — task IDs that must merge first. Empty = parallel-safe right now.
- **Est** — engineering hours estimate.
- **||** — parallel cluster tag. Tasks sharing a tag can be picked up by separate contributors at the same time.

---

## Cluster A — Repo scaffolding (sequential start)

### T-001 — Create Xcode project + git repo
- **Scope:** Init `DODApp.xcodeproj`, iOS 17 minimum, universal (iPhone+iPad), Swift 5.9+. Create git repo with `.gitignore` (Xcode, SPM, `.DS_Store`, `*.xcconfig` for secrets).
- **Files:** `DODApp.xcodeproj/`, `App/DODApp.swift`, `App/RootView.swift`, `.gitignore`, `README.md` (stub).
- **AC:** `git status` clean; `xcodebuild -scheme DODApp -destination 'platform=iOS Simulator,name=iPhone 15'` succeeds; app launches to a black screen.
- **Deps:** —
- **Est:** 2h
- **||:** A-start

### T-002 — Add SwiftLint config
- **Scope:** Add `.swiftlint.yml` with rules per constitution §10. Wire as a build-phase script. Warnings fail CI.
- **Files:** `.swiftlint.yml`, build-phase script.
- **AC:** `swiftlint --strict` exits 0 on empty project. Intentional rule violation in a scratch file fails CI.
- **Deps:** T-001
- **Est:** 1h
- **||:** A-config

### T-003 — Add swift-format + pre-commit
- **Scope:** Add `.swift-format` (Apple defaults), a `bin/format.sh`, and a pre-commit hook docs entry.
- **Files:** `.swift-format`, `bin/format.sh`, `README.md`.
- **AC:** `swift-format format --in-place -r .` produces no diff on a freshly cloned repo.
- **Deps:** T-001
- **Est:** 1h
- **||:** A-config

### T-004 — CI workflow (GitHub Actions)
- **Scope:** `.github/workflows/ci.yml` builds + runs all unit tests on every PR. Cache derived data. Lint job runs in parallel.
- **Files:** `.github/workflows/ci.yml`.
- **AC:** Open a draft PR; CI completes green within 10 minutes; failing the lint deliberately fails the run.
- **Deps:** T-001, T-002
- **Est:** 2h
- **||:** A-config

### T-005 — Create 11 Package.swift skeletons
- **Scope:** Add `Packages/DODDomain`, `DODSupport`, `DODDesignSystem`, `DODAnalytics`, `DODNetworking`, `DODPersistence`, `DODFeatureFeed`, `DODFeatureCategories`, `DODFeatureSearch`, `DODFeatureRecipeDetail`, `DODFeatureSaved`. Each with empty `Sources/` and `Tests/` and a single placeholder `.swift` file so the package compiles.
- **Files:** 11× `Packages/*/Package.swift`, 11× `Sources/*/Placeholder.swift`, 11× `Tests/*/PlaceholderTests.swift`.
- **AC:** Each `swift build` inside its own package directory succeeds; `swift test` finds and runs zero tests cleanly.
- **Deps:** T-001
- **Est:** 3h
- **||:** A-modules

### T-006 — Wire packages into the app target
- **Scope:** Add all 11 packages as local Swift Package dependencies of the `DODApp` Xcode target. Verify the app still builds and launches.
- **Files:** Xcode project file; minor `DODApp.swift` imports to confirm linkage.
- **AC:** `xcodebuild` succeeds; `import DODDomain` (etc.) resolves in the app target.
- **Deps:** T-005
- **Est:** 2h
- **||:** A-modules

---

## Cluster B — Foundation modules (parallel after Cluster A)

### DODDomain (||: B-domain)

### T-010 — Recipe + RecipeListItem
- **Scope:** Define `Recipe` and `RecipeListItem` structs per plan §2. Sendable, Hashable, Identifiable. Detail fields are optionals (populated post-JSON-LD).
- **Files:** `Sources/DODDomain/Recipe.swift`, `RecipeListItem.swift`.
- **AC:** Type conformance unit tests pass (Hashable equality, Codable round-trip).
- **Deps:** T-006
- **Est:** 2h

### T-011 — Category + ingredient/instruction/video/nutrition value types
- **Scope:** Define `Category`, `RecipeIngredient`, `RecipeInstruction`, `RecipeVideo`, `RecipeNutrition` per plan §2.
- **Files:** `Sources/DODDomain/Category.swift`, `RecipeIngredient.swift`, `RecipeInstruction.swift`, `RecipeVideo.swift`, `RecipeNutrition.swift`.
- **AC:** Unit tests for each conformance.
- **Deps:** T-006
- **Est:** 2h

### DODSupport (||: B-support)

### T-020 — HTMLSanitizer
- **Scope:** Strip HTML tags + decode entities from a WP excerpt to plain text. Pure function.
- **Files:** `Sources/DODSupport/HTMLSanitizer.swift`, `Tests/HTMLSanitizerTests.swift`.
- **AC:** 8+ golden cases pass (entities, nested tags, empty input, multibyte).
- **Deps:** T-006
- **Est:** 2h

### T-021 — StringHasher
- **Scope:** SHA256 hex digest of a lowercased, trimmed string. Used for hashed search-query telemetry (AC-3.6).
- **Files:** `Sources/DODSupport/StringHasher.swift`, `Tests/StringHasherTests.swift`.
- **AC:** Stable digest for the same input; differs by 1 character difference.
- **Deps:** T-006
- **Est:** 1h

### T-022 — Logger
- **Scope:** OSLog wrapper with category-per-subsystem. Public API: `Logger.network`, `Logger.persistence`, `Logger.ui`. Never logs user input strings (redact at the boundary).
- **Files:** `Sources/DODSupport/Logger.swift`, `Tests/LoggerTests.swift`.
- **AC:** Logged messages reach `os_log` (verified via lightweight subscriber in test); redaction helper truncates user-input fields.
- **Deps:** T-006
- **Est:** 1h

### DODDesignSystem (||: B-design)

### T-030 — Color palette + asset catalog
- **Scope:** Asset catalog with light/dark variants for every semantic color from plan §5. `DODColor` enum exposes them as `Color`.
- **Files:** `Sources/DODDesignSystem/Resources/Colors.xcassets`, `Sources/DODDesignSystem/Colors.swift`.
- **AC:** Snapshot test renders a swatch grid in light + dark on iPhone + iPad; no missing-asset warnings.
- **Deps:** T-006
- **Est:** 2h

### T-031 — Typography ramp
- **Scope:** `DODType` enum exposing system-font styles with Dynamic Type binding. AX5 supported.
- **Files:** `Sources/DODDesignSystem/Typography.swift`, snapshot tests at default + AX5 sizes.
- **AC:** Snapshot tests pass at `.large` and `.accessibility5`.
- **Deps:** T-006
- **Est:** 2h

### T-032 — Spacing constants
- **Scope:** `DODSpacing` enum with the 4/8/12/16/24/32 grid.
- **Files:** `Sources/DODDesignSystem/Spacing.swift`.
- **AC:** Compiles; no public surface change checked by snapshot tests in T-033+.
- **Deps:** T-006
- **Est:** 0.5h

### T-033 — EmptyState component
- **Scope:** `EmptyState(title:, body:, action:)` — icon + title + body + optional CTA button.
- **Files:** `Sources/DODDesignSystem/Components/EmptyState.swift`, snapshot tests.
- **AC:** Snapshot light/dark, iPhone/iPad, with and without CTA.
- **Deps:** T-030, T-031, T-032
- **Est:** 2h

### T-034 — OfflineBanner component
- **Scope:** Non-blocking top banner per CC-2. Slides in on offline, slides out on reconnect. Pure SwiftUI.
- **Files:** `OfflineBanner.swift`, snapshot tests.
- **AC:** Snapshot pinned visible; animation timing covered by a 100ms unit test on the view model.
- **Deps:** T-030, T-031, T-032
- **Est:** 2h

### T-035 — LoadingSkeleton component
- **Scope:** Shimmer-skeleton rows for use in list and detail screens. Respects Reduce Motion (static gradient when set).
- **Files:** `LoadingSkeleton.swift`, snapshot + reduce-motion tests.
- **AC:** Snapshots pass; with Reduce Motion enabled, animation is replaced with a static fill.
- **Deps:** T-030, T-031, T-032
- **Est:** 2h

### T-036 — Snackbar component
- **Scope:** Auto-dismissing bottom snackbar with optional Undo button. Used for save-toggle undo (AC-5.1) and recipe-unavailable (AC-4.11).
- **Files:** `Snackbar.swift`, snapshot + dismiss-timer tests.
- **AC:** Snapshot pass; dismiss-timer test asserts 4s default; explicit `Undo` button visible when action is provided.
- **Deps:** T-030, T-031, T-032
- **Est:** 2h

### T-037 — RecipeCard component
- **Scope:** Reusable list row: hero image (AsyncImage placeholder), title (1–2 lines), excerpt (2 lines), total-time chip. Used by Feed, Category, Search, Saved.
- **Files:** `RecipeCard.swift`, snapshot tests.
- **AC:** Snapshot light/dark, iPhone/iPad. Truncates correctly at AX5.
- **Deps:** T-030, T-031, T-032
- **Est:** 3h

### DODAnalytics (||: B-analytics)

### T-040 — AnalyticsEvent sealed enum
- **Scope:** Sealed enum listing every allowlisted event from constitution §9 (`appOpen`, `screenView`, `recipeView`, `recipeSaved`, `recipeUnsaved`, `recipeSearched`, `recipeShared`, `offlineRead`). Compiler-enforced allowlist.
- **Files:** `Sources/DODAnalytics/AnalyticsEvent.swift`, `Tests/AnalyticsEventTests.swift`.
- **AC:** Cannot construct an unknown event (proven by a doc-comment + a compile-check test in a private fixture file).
- **Deps:** T-006
- **Est:** 1h

### T-041 — Telemetry wrapper
- **Scope:** Add `TelemetryDeck/SwiftSDK` SPM dep to `DODAnalytics`. `Telemetry.start(appID:)` and `Telemetry.send(_ event: AnalyticsEvent)`. No other code in the app imports TelemetryDeck.
- **Files:** `Package.swift` (deps), `Sources/DODAnalytics/Telemetry.swift`, `Tests/TelemetryTests.swift`.
- **AC:** Test injects a fake transport, sends each `AnalyticsEvent`, asserts the right payload shape; verifies no PII fields leak.
- **Deps:** T-040
- **Est:** 2h

---

## Cluster C — Networking module (after Cluster B Domain + Support)

### T-050 — WPClientError + URLSession baseline
- **Scope:** Typed error enum (`networkUnavailable`, `httpStatus(Int)`, `decoding`, `timeout`). `WPRestClient` initializer takes a `URLSession` for testability.
- **Files:** `Sources/DODNetworking/WPClientError.swift`, `WPRestClient.swift` skeleton.
- **AC:** Compile + unit test that maps URLSession errors to WPClientError cases.
- **Deps:** T-010, T-011
- **Est:** 1.5h

### T-051 — WPRestClient.posts (paged)
- **Scope:** `func posts(categoryID: Int?, page: Int) async throws -> [RecipeListItem]`. Uses `_fields` to keep payload small. 20 per page (CL-2).
- **Files:** `WPRestClient.swift`, fixture JSON in tests.
- **AC:** Unit test against checked-in fixture returns parsed items; pagination param appears in URL.
- **Deps:** T-050
- **Est:** 2h

### T-052 — WPRestClient.categories
- **Scope:** `func categories() async throws -> [Category]`, `per_page=100`, `hide_empty=true`.
- **Files:** `WPRestClient.swift`, fixture.
- **AC:** Categories parsed and sorted; `count==0` already filtered by the API param.
- **Deps:** T-050
- **Est:** 1.5h

### T-053 — WPRestClient.search
- **Scope:** `func search(query: String, page: Int) async throws -> [RecipeListItem]`. URL-encodes the query.
- **Files:** `WPRestClient.swift`, fixture.
- **AC:** Unit tests cover empty, 1-char (returns empty by client guard — actual debounce in feature), happy path.
- **Deps:** T-050
- **Est:** 1.5h

### T-054 — WPRestClient.media (image size resolution)
- **Scope:** `func media(id: Int) async throws -> MediaSizes`. Returns `medium_large` and largest-≤-2048px URLs per CL-6.
- **Files:** `WPRestClient.swift`, `MediaSizes.swift`, fixture.
- **AC:** Fixture media response yields the correct URLs for list and hero sizes.
- **Deps:** T-050
- **Est:** 2h

### T-055 — NetworkMonitor
- **Scope:** Actor wrapping `NWPathMonitor`. Exposes `var isOnline: Bool` and an `AsyncStream<Bool>` of changes.
- **Files:** `Sources/DODNetworking/NetworkMonitor.swift`, tests with a fake path provider.
- **AC:** Stream emits on simulated change.
- **Deps:** T-006
- **Est:** 2h

### T-056 — RecipePageFetcher
- **Scope:** `func html(for url: URL) async throws -> String`. Sets `Accept-Encoding: gzip`. 30s timeout.
- **Files:** `RecipePageFetcher.swift`, fixture.
- **AC:** Test using stubbed `URLSession` returns the expected body.
- **Deps:** T-050
- **Est:** 1.5h

### T-057 — JSONLDRecipeParser: extract <script> blocks
- **Scope:** Pure-Swift regex/scan to pull every `<script type="application/ld+json">…</script>` payload from an HTML string. No HTML parser dependency.
- **Files:** `JSONLDRecipeParser.swift`, tests with checked-in mini HTML.
- **AC:** Test with 3-block HTML returns exactly 3 strings; malformed boundaries gracefully return what is parseable.
- **Deps:** T-006
- **Est:** 2h

### T-058 — JSONLDRecipeParser: map @type:Recipe → Recipe
- **Scope:** Walk parsed JSON, find object with `@type == "Recipe"` (handles `@graph` envelopes). Map fields to `Recipe` partial.
- **Files:** `JSONLDRecipeParser.swift`, tests.
- **AC:** Single-recipe fixture yields populated `Recipe`; missing block returns typed `.notFound` error.
- **Deps:** T-057, T-010, T-011
- **Est:** 3h

### T-059 — JSONLDRecipeParser: instruction shape variants (R-4)
- **Scope:** Handle both `recipeInstructions` as `[String]` and `[HowToStep]`. Same for `[HowToSection]` containing steps.
- **Files:** `JSONLDRecipeParser.swift`, fixture HTMLs covering both shapes.
- **AC:** Both fixtures parse to equivalent `[RecipeInstruction]` arrays.
- **Deps:** T-058
- **Est:** 2h

### T-060 — ImageLoader actor
- **Scope:** Actor with `func image(for: URL) async throws -> Data`. Uses `URLSession` + disk cache (passed in from Persistence later — for now an in-memory `NSCache`).
- **Files:** `ImageLoader.swift`, tests with stub session.
- **AC:** Concurrent calls for the same URL coalesce into a single network request.
- **Deps:** T-050
- **Est:** 2h

### T-061 — Golden-file HTML fixtures
- **Scope:** Check in 5 representative HTML files from the live blog: cake, savory, soup, bread, the temperature-chart non-recipe.
- **Files:** `Tests/DODNetworkingTests/Fixtures/*.html`.
- **AC:** Files committed (LFS not needed at this size). Each <1 MB.
- **Deps:** —
- **Est:** 1h

### T-062 — Golden-file parser tests
- **Scope:** For each fixture: assert that 4 parse to a populated `Recipe`, the temperature-chart fixture fails with `.notFound`. Lock the JSON-LD contract.
- **Files:** `Tests/DODNetworkingTests/GoldenParseTests.swift`.
- **AC:** All assertions pass.
- **Deps:** T-058, T-059, T-061
- **Est:** 2h

---

## Cluster D — Persistence module (after Cluster B Domain)

### T-070 — CachedRecipe @Model
- **Scope:** `@Model final class CachedRecipe` per plan §2.
- **Files:** `Sources/DODPersistence/CachedRecipe.swift`.
- **AC:** Compiles; in-memory `ModelContainer` test inserts + fetches one row.
- **Deps:** T-010
- **Est:** 2h

### T-071 — CachedListPage @Model
- **Scope:** Per plan §2.
- **Files:** `CachedListPage.swift`.
- **AC:** In-memory test inserts a page keyed `home`, fetches it back.
- **Deps:** T-006
- **Est:** 1h

### T-072 — CachedImage @Model
- **Scope:** Per plan §2.
- **Files:** `CachedImage.swift`.
- **AC:** Insert + fetch test passes.
- **Deps:** T-006
- **Est:** 1h

### T-073 — RecipeStore CRUD
- **Scope:** `RecipeStore` actor with `save(_ recipe: Recipe)`, `cache(_ listItem: RecipeListItem)`, `recipe(id:) -> Recipe?`, `toggleSaved(id:) async throws`.
- **Files:** `RecipeStore.swift`, tests.
- **AC:** Round-trip tests for each method.
- **Deps:** T-070, T-071, T-072
- **Est:** 3h

### T-074 — CachePolicy LRU (100 unsaved)
- **Scope:** `evictIfNeeded()` keeps unsaved CachedRecipe rows ≤ 100 by oldest `lastViewedAt`. Saved rows never evicted (NFR-1).
- **Files:** `CachePolicy.swift`, tests.
- **AC:** Insert 110 unsaved + 10 saved; after policy run, count is 110 (100 unsaved + 10 saved).
- **Deps:** T-073
- **Est:** 2h

### T-075 — CachePolicy image budget (200 MB)
- **Scope:** Evict oldest non-pinned images until total `bytes` ≤ 200 MB (NFR-2).
- **Files:** `CachePolicy.swift`, tests.
- **AC:** Test with synthetic 1 MB rows asserts post-policy total.
- **Deps:** T-074
- **Est:** 2h

### T-076 — Blocklist logic for AC-1.7
- **Scope:** `RecipeStore.markJSONLDFailed(id:)`, `clearBlocklist()` (used by pull-to-refresh). Queries that drive lists exclude rows with `jsonLDFailedAt != nil`.
- **Files:** `RecipeStore.swift`, tests.
- **AC:** Insert blocklisted row + healthy row; list query returns only the healthy one. After `clearBlocklist()`, both appear.
- **Deps:** T-073
- **Est:** 2h

### T-077 — SwiftData schema version + migration template
- **Scope:** Define `Schema(versionedSchema: V1.self)`. Add `MigrationPlan` skeleton with a doc note: future schema changes are additive-only (R-5).
- **Files:** `SchemaV1.swift`, `MigrationPlan.swift`, `MIGRATION.md`.
- **AC:** App boots with V1 store; doc reviewed.
- **Deps:** T-070, T-071, T-072
- **Est:** 2h

---

## Cluster E — Feature modules (parallel after Cluster C + D)

### DODFeatureFeed (||: E-feed)

### T-080 — FeedRow binding
- **Scope:** Adapter from `RecipeListItem` to `RecipeCard` (DesignSystem). Lives in feature for now; if reused elsewhere unchanged, promote later.
- **Files:** `FeedRow.swift`, snapshot test.
- **AC:** Snapshot pass.
- **Deps:** T-037, T-010
- **Est:** 1h

### T-081 — FeedViewModel: initial load + infinite scroll
- **Scope:** `@Observable` view model. Loads page 1 on appear, pages on bottom-trigger. Holds offline flag from injected `NetworkMonitor`.
- **Files:** `FeedViewModel.swift`, tests with fake client.
- **AC:** AC-1.1, AC-1.2 covered by unit tests.
- **Deps:** T-051, T-055, T-073
- **Est:** 3h

### T-082 — FeedView pull-to-refresh
- **Scope:** SwiftUI view with `.refreshable`. Calls VM refresh, which clears blocklist (T-076).
- **Files:** `FeedView.swift`, UI test.
- **AC:** AC-1.4 + the AC-1.7 reset behavior covered.
- **Deps:** T-081, T-076
- **Est:** 2h

### T-083 — Offline banner integration
- **Scope:** Wire `OfflineBanner` to `FeedViewModel.isOffline`. Cached page hydration when offline.
- **Files:** `FeedView.swift`, `FeedViewModel.swift`.
- **AC:** AC-1.6 covered.
- **Deps:** T-082, T-034
- **Est:** 2h

### T-084 — First-launch offline empty state
- **Scope:** Show `EmptyState` with "You need internet to load recipes the first time" + Retry when no cached page exists and offline.
- **Files:** `FeedView.swift`.
- **AC:** AC-1.5 covered.
- **Deps:** T-083, T-033
- **Est:** 1h

### T-085 — List filter for blocklisted posts
- **Scope:** Query path uses the blocklist-aware list method from T-076.
- **Files:** `FeedViewModel.swift`.
- **AC:** AC-1.7 covered by unit test.
- **Deps:** T-076, T-081
- **Est:** 1h

### T-086 — Feed AC sweep tests
- **Scope:** Audit `FeedViewModelTests` + `FeedViewTests` ensure every AC-1.* maps to a named test.
- **Files:** test additions, no production code.
- **AC:** Audit checklist in PR description maps AC-1.1..1.7 → test names.
- **Deps:** T-080..T-085
- **Est:** 2h

### DODFeatureCategories (||: E-cats)

### T-090 — CategoryListViewModel + view
- **Scope:** Fetches categories, alpha-sorts, hides count==0 (already filtered server-side; double-check client-side).
- **Files:** `CategoryListViewModel.swift`, `CategoryListView.swift`, tests.
- **AC:** AC-2.1, AC-2.2 covered.
- **Deps:** T-052
- **Est:** 2h

### T-091 — CategoryRecipesViewModel + view
- **Scope:** Paged list scoped to a category id. Reuses `FeedRow` indirectly via `RecipeCard`.
- **Files:** `CategoryRecipesViewModel.swift`, `CategoryRecipesView.swift`, tests.
- **AC:** AC-2.3 covered.
- **Deps:** T-051, T-037
- **Est:** 3h

### T-092 — Categories AC sweep
- **Scope:** Tests for AC-2.4 (empty-zero hidden), AC-2.5 (error state).
- **Files:** test additions.
- **AC:** Mapping documented.
- **Deps:** T-090, T-091
- **Est:** 1.5h

### DODFeatureSearch (||: E-search)

### T-100 — SearchViewModel debounce
- **Scope:** `@Observable` VM with 300ms debounce via `task(id: query)` + `Task.sleep`.
- **Files:** `SearchViewModel.swift`, tests using a manual clock.
- **AC:** AC-3.1 covered; debounce verified.
- **Deps:** T-053
- **Est:** 2h

### T-101 — SearchView UI + empty/error
- **Scope:** Text field with clear button. Results list (RecipeCard). Empty + offline states.
- **Files:** `SearchView.swift`.
- **AC:** AC-3.3, AC-3.4, AC-3.5, AC-3.7 covered.
- **Deps:** T-100, T-037, T-033, T-034
- **Est:** 3h

### T-102 — Hashed-query analytics
- **Scope:** On each finalized search, call `Telemetry.send(.recipeSearched(queryHash:))`. Hash via `StringHasher`. Raw string never sent.
- **Files:** `SearchViewModel.swift`, test asserting payload.
- **AC:** AC-3.6 covered; assertion that raw query is absent from outgoing payload.
- **Deps:** T-100, T-041, T-021
- **Est:** 1h

### T-103 — Search AC sweep
- **Scope:** AC-3.2 (title+excerpt scope; ingredient-body deferred — add an in-app note in the empty state when results look sparse).
- **Files:** `SearchView.swift`, test.
- **AC:** Mapping documented.
- **Deps:** T-101
- **Est:** 1h

### DODFeatureRecipeDetail (||: E-detail, largest cluster)

### T-110 — RecipeDetailViewModel skeleton
- **Scope:** Loads cached `RecipeListItem` instantly for header; triggers async detail fetch via `RecipePageFetcher` + `JSONLDRecipeParser`. Surfaces loading/error states.
- **Files:** `RecipeDetailViewModel.swift`, tests with fake fetcher.
- **AC:** Header renders immediately; detail fields populate after fetch resolves.
- **Deps:** T-056, T-058, T-059, T-073
- **Est:** 3h

### T-111 — Detail header
- **Scope:** Hero image (large size), title, short description, meta row (prep/cook/total/servings).
- **Files:** `RecipeDetailView.swift`, snapshot.
- **AC:** AC-4.1 covered.
- **Deps:** T-110, T-037, T-054, T-060
- **Est:** 2h

### T-112 — Ingredient section + checkbox row
- **Scope:** `IngredientCheckRow` with tap-to-strike. State held in VM, not persisted (AC-4.2).
- **Files:** `IngredientCheckRow.swift`, section view, tests.
- **AC:** AC-4.2 covered; VoiceOver announces toggle state.
- **Deps:** T-110
- **Est:** 2h

### T-113 — Instruction section
- **Scope:** `InstructionStep` numbered rows; readable line spacing; Dynamic Type to AX5.
- **Files:** `InstructionStep.swift`, section view, snapshot at AX5.
- **AC:** AC-4.3 covered.
- **Deps:** T-110, T-031
- **Est:** 2h

### T-114 — Video player section
- **Scope:** AVKit `VideoPlayer` inline when `recipe.video != nil`. PiP enabled. Hidden block when nil.
- **Files:** detail view additions, tests.
- **AC:** AC-4.4, AC-4.5 covered.
- **Deps:** T-110
- **Est:** 3h

### T-115 — RelatedRecipesStrip
- **Scope:** Horizontal scroll of 3–4 related recipes from same primary category. Hidden when offline (AC-5.6).
- **Files:** `RelatedRecipesStrip.swift`, tests.
- **AC:** AC-4.6, AC-5.6 covered.
- **Deps:** T-110, T-051
- **Est:** 3h

### T-116 — Save button + haptic
- **Scope:** Heart icon in nav bar. Toggles `isSaved` via `RecipeStore`. Haptic feedback. Snackbar with Undo on unsave.
- **Files:** `RecipeDetailView.swift`, VM, tests.
- **AC:** AC-4.7, AC-5.1 covered.
- **Deps:** T-110, T-076, T-036
- **Est:** 2h

### T-117 — Share button + iOS share sheet
- **Scope:** ShareLink with `recipe.canonicalURL`. Fires `Telemetry.send(.recipeShared)`.
- **Files:** `RecipeDetailView.swift`, tests.
- **AC:** AC-4.8, AC-6.1, AC-6.2, AC-6.3 covered.
- **Deps:** T-110, T-041
- **Est:** 1h

### T-118 — Offline recipe rendering
- **Scope:** When offline and recipe is saved, all sections render from cache; no network calls.
- **Files:** VM logic, tests.
- **AC:** AC-4.9, AC-5.4 covered.
- **Deps:** T-110, T-073
- **Est:** 2h

### T-119 — Recipe-unavailable failure path
- **Scope:** On JSON-LD parse failure: nav pop + snackbar; mark post via `markJSONLDFailed`.
- **Files:** VM logic, view glue, tests.
- **AC:** AC-4.11 covered.
- **Deps:** T-110, T-076, T-036
- **Est:** 2h

### T-120 — VoiceOver pass on detail
- **Scope:** Hero image alt = recipe title. Ingredient checkboxes announce state. Instruction list reachable in order.
- **Files:** accessibility modifiers in detail screen.
- **AC:** AC-4.10 covered; Accessibility Inspector clean.
- **Deps:** T-111, T-112, T-113
- **Est:** 2h

### T-121 — Detail AC sweep
- **Scope:** Final audit; every AC-4.* and AC-6.* has a named test.
- **Files:** test additions.
- **AC:** Mapping documented in PR description.
- **Deps:** T-110..T-120
- **Est:** 2h

### DODFeatureSaved (||: E-saved)

### T-130 — SavedViewModel
- **Scope:** SwiftData query for `CachedRecipe` where `isSaved == true`, newest-saved-first.
- **Files:** `SavedViewModel.swift`, tests.
- **AC:** AC-5.3 covered.
- **Deps:** T-073
- **Est:** 2h

### T-131 — SavedView
- **Scope:** List of `RecipeCard`s. Tap → `RecipeDetailView`.
- **Files:** `SavedView.swift`, snapshot.
- **AC:** Snapshot pass; navigation test asserts tap behavior.
- **Deps:** T-130, T-037
- **Est:** 1.5h

### T-132 — Save action pre-download
- **Scope:** On `toggleSaved` true→: fetch + persist full `Recipe` body and both image sizes within 5s on a normal connection. Background `Task`.
- **Files:** `RecipeStore.swift` (extend), tests with fake clock.
- **AC:** AC-5.2 covered.
- **Deps:** T-073, T-060, T-058
- **Est:** 3h

### T-133 — Saved empty state
- **Scope:** Shows `EmptyState` with "Tap the heart on any recipe to save it for offline."
- **Files:** `SavedView.swift`.
- **AC:** AC-5.8 covered.
- **Deps:** T-131, T-033
- **Est:** 0.5h

### T-134 — Offline saved-recipe read (integration test)
- **Scope:** Integration test simulating offline + saved recipe: all sections render with zero network calls.
- **Files:** `Tests/SavedOfflineTests.swift`.
- **AC:** AC-5.4 covered.
- **Deps:** T-118, T-132
- **Est:** 2h

### T-135 — Inline video offline placeholder
- **Scope:** When offline + saved + recipe has video, show "Video unavailable offline" placeholder card.
- **Files:** detail view branch.
- **AC:** AC-5.5 covered.
- **Deps:** T-114, T-118
- **Est:** 1h

### T-136 — Saved AC sweep
- **Scope:** Audit; every AC-5.* has a named test. AC-5.7 documented in onboarding-less first-launch FAQ in README.
- **Files:** test additions, README note.
- **AC:** Mapping documented.
- **Deps:** T-130..T-135
- **Est:** 1.5h

---

## Cluster F — App composition (after Cluster E)

### T-140 — AppDependencies composition root
- **Scope:** Single struct that constructs and holds: `WPRestClient`, `RecipeStore`, `NetworkMonitor`, `Telemetry`, `ImageLoader`. Injected into each feature root view.
- **Files:** `App/AppDependencies.swift`.
- **AC:** App builds; preview-only `MockDependencies` exists for SwiftUI previews.
- **Deps:** E-cluster done
- **Est:** 2h

### T-141 — RootView TabView (iPhone)
- **Scope:** Tab bar with Feed / Categories / Search / Saved. Calls `Telemetry.send(.appOpen)` on first appear.
- **Files:** `App/RootView.swift`, `App/ContentTabs.swift`.
- **AC:** UI test verifies all four tabs reachable.
- **Deps:** T-140
- **Est:** 2h

### T-142 — NavigationSplitView for iPad
- **Scope:** On iPad horizontal regular, use `NavigationSplitView` with sidebar (Feed/Categories/Search/Saved) + content + detail. Stack on iPhone (CC-8).
- **Files:** `RootView.swift` adaptive logic.
- **AC:** Snapshot at iPad 12.9" + UI test.
- **Deps:** T-141
- **Est:** 3h

### T-143 — Telemetry screen-view wiring
- **Scope:** Each tab and detail screen sends `.screenView` on appear. Detail open sends `.recipeView`.
- **Files:** each feature view, `Telemetry` helper modifier.
- **AC:** Test confirms one event per appearance, no duplicates on tab re-selection within 1s.
- **Deps:** T-141
- **Est:** 1.5h

---

## Cluster G — iPad adaptation pass (after F)

### T-150 — Feed iPad layout
- **Scope:** Two-column grid on iPad regular; one-column on iPhone. List → split secondary on iPad.
- **Files:** `FeedView.swift`.
- **AC:** Snapshot at iPad portrait + landscape.
- **Deps:** T-142
- **Est:** 2h

### T-151 — Categories iPad layout
- **Scope:** Sidebar list + secondary recipe grid on iPad. Stack on iPhone.
- **Files:** `CategoryListView.swift`, `CategoryRecipesView.swift`.
- **AC:** Snapshot.
- **Deps:** T-142
- **Est:** 2h

### T-152 — Search iPad layout
- **Scope:** Search bar persistently visible on iPad; results in secondary column.
- **Files:** `SearchView.swift`.
- **AC:** Snapshot.
- **Deps:** T-142
- **Est:** 1.5h

### T-153 — Recipe Detail iPad layout
- **Scope:** Two-column on iPad: hero + ingredients in primary, instructions in secondary. Single column on iPhone.
- **Files:** `RecipeDetailView.swift`.
- **AC:** Snapshot.
- **Deps:** T-142
- **Est:** 3h

### T-154 — Saved iPad layout
- **Scope:** Grid like Feed.
- **Files:** `SavedView.swift`.
- **AC:** Snapshot.
- **Deps:** T-142, T-150
- **Est:** 1h

---

## Cluster H — Accessibility audit pass

### T-160 — Dynamic Type AX5 sweep
- **Scope:** Open every screen at AX5 in simulator; fix overflow, truncation, tap-targets.
- **Files:** various.
- **AC:** Snapshot suite at AX5 added for every top-level view.
- **Deps:** All features
- **Est:** 4h

### T-161 — VoiceOver label audit
- **Scope:** Every interactive element has a label; every meaningful image has a description; every screen has a logical reading order.
- **Files:** various; mostly modifier additions.
- **AC:** Accessibility Inspector reports zero issues on each screen.
- **Deps:** All features
- **Est:** 3h

### T-162 — Contrast audit in light + dark
- **Scope:** Verify every text/background pair meets WCAG AA. Adjust palette tokens if needed.
- **Files:** `Colors.xcassets`, possibly `Colors.swift`.
- **AC:** Audit report attached to PR; failing pairs fixed.
- **Deps:** T-030
- **Est:** 2h

---

## Cluster I — Performance pass

### T-170 — Cold launch trace + fixes
- **Scope:** Instruments cold-launch run on iPhone 13. Identify and remove top-3 contributors above budget.
- **Files:** likely `DODApp.swift`, dependency wiring.
- **AC:** Cold launch < 1.5s on iPhone 13 baseline (CC-7).
- **Deps:** T-141
- **Est:** 3h

### T-171 — List scroll instrument
- **Scope:** Instruments time-profile of feed scroll. Fix dropped frames.
- **Files:** `FeedView.swift`, `RecipeCard.swift`.
- **AC:** 60fps sustained; no dropped frames in 30s scroll test.
- **Deps:** T-080, T-082
- **Est:** 2h

### T-172 — CI perf gate
- **Scope:** XCTest performance test for cold launch + scroll. Wire into CI; regression > 10% fails.
- **Files:** `DODPerformanceTests/`, CI yml.
- **AC:** Two perf tests pass on CI runner; intentionally added sleep makes them fail.
- **Deps:** T-170, T-171
- **Est:** 2h

---

## Cluster J — Release prep

### T-180 — App icon + asset catalog
- **Scope:** Add app icon set (all required sizes) from blog-provided artwork.
- **Files:** `Assets.xcassets/AppIcon.appiconset/`.
- **AC:** No missing-size warnings; archive builds clean.
- **Deps:** Owner provides artwork
- **Est:** 1h

### T-181 — Screenshots
- **Scope:** Generate App Store screenshots: 6.5", 6.7" iPhone, 12.9" iPad. Two per device (Feed + Recipe Detail) minimum.
- **Files:** `Marketing/Screenshots/`.
- **AC:** All required device sizes present.
- **Deps:** All features complete
- **Est:** 3h

### T-182 — App Privacy questionnaire
- **Scope:** Draft Apple App Store privacy answers exactly matching constitution §9. Document inside repo.
- **Files:** `Marketing/AppPrivacy.md`.
- **AC:** Reviewed line-by-line against constitution §9.
- **Deps:** T-041
- **Est:** 1h

### T-183 — Marketing copy
- **Scope:** App Store description, keywords, what's new.
- **Files:** `Marketing/AppStoreCopy.md`.
- **AC:** Owner-approved.
- **Deps:** —
- **Est:** 1.5h

### T-184 — TestFlight first beta
- **Scope:** Archive + upload to App Store Connect. Configure TestFlight build with 10 internal testers.
- **Files:** none (App Store Connect config).
- **AC:** Build delivered to testers; install + launch sanity verified.
- **Deps:** Everything in A–I complete
- **Est:** 2h

---

## Phase 6 — Consultant pass

Added 2026-05-23 by the consultant-pass amendment. Implements the new spec contracts: CC-9 (visual density), US-7 (Cook Mode), US-8 (Onboarding). Authorized in `clarifications.md` CL-16, CL-17, CL-18. High-level grouping mirrors `plan.md` "Phase 6 work cluster — Consultant pass".

### T-300 — Card visual density (CC-9)
- **Scope:** Switch Feed / Categories / Search / Saved from 1-column compact (T-150-era) to 2-column compact + 3-column regular. Reduce RecipeCard hero height so ≥3 rows are visible above the fold on iPhone 13 baseline. Snapshot tests at iPhone 13 + iPad 12.9".
- **Files:** `Packages/DODDesignSystem/Sources/DODDesignSystem/AdaptiveGrid.swift`, `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift`, the four FeatureXxxView files, snapshot suite under `Packages/DODDesignSystem/Tests/`.
- **AC:** CC-9; visual regression snapshots updated.
- **Deps:** — (independent of T-301..T-305).
- **Est:** 3h
- **||:** F6-cards

### T-301 — App icon placeholder + asset catalog
- **Scope:** Populate `App/Assets.xcassets/AppIcon.appiconset/` with every required iPhone + iPad size from a single 1024 marketing master (placeholder artwork until the owner ships final). Unblocks TestFlight "missing icon" rejection.
- **Files:** `App/Assets.xcassets/AppIcon.appiconset/Contents.json`, PNG variants, possibly `Marketing/AppIcon.md`.
- **AC:** Archive build succeeds with no "missing required icon" warning; closes T-180 part 1.
- **Deps:** —
- **Est:** 1h
- **||:** F6-icon

### T-302 — Recipe detail polish
- **Scope:** Sticky save + share buttons on `RecipeDetailView` so they remain reachable when scrolled past hero. Hero overlay (title + meta row over a gradient at the bottom of the hero image) anchoring meta at the top of the visible content area. Refines AC-4.1, AC-4.7, AC-4.8 without changing the contract.
- **Files:** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift`, new `RecipeDetailHero.swift` if cleanly extractable, snapshot tests.
- **AC:** AC-4.1, AC-4.7, AC-4.8 still pass; new snapshots locked.
- **Deps:** —
- **Est:** 3h
- **||:** F6-detail

### T-303 — Onboarding sheet (US-8)
- **Scope:** First-launch single-screen modal sheet over Feed. Three bullets, "Get cooking" dismiss button, `dod.onboardingCompletedV1` UserDefaults flag.
- **Files:** New `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/OnboardingSheet.swift` (or inside `DODFeatureFeed` if cross-app reuse not needed), `App/RootView.swift` (or `App/AppDependencies.swift`) for the flag check + presentation glue, snapshot + unit tests.
- **AC:** AC-8.1, AC-8.2, AC-8.3.
- **Deps:** — (T-303 is independent, but reads cleaner once T-300 lands so the underlying Feed looks final in screenshots).
- **Est:** 3h
- **||:** F6-onb

### T-304 — Cook Mode (US-7)
- **Scope:** Full-screen takeover from recipe detail. "Cook Now" CTA, step counter, large step text, ingredients drawer, `isIdleTimerDisabled` toggle with restore-on-exit, swipe + tap step navigation, Done state on last step, shared ingredient-check state with detail.
- **Files:** New `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeView.swift` + `CookModeViewModel.swift` + `IdleTimerCoordinator.swift` (UIKit toggle wrapper, mockable), updates to `RecipeDetailView.swift` + `RecipeDetailViewModel.swift` for the Cook Now button and shared check state, snapshot tests, L3 UI smoke test.
- **AC:** AC-7.1 through AC-7.6.
- **Deps:** T-302 (merge-order, not functional — both touch `RecipeDetailView`).
- **Est:** 6h (split across 2 PRs if it grows)
- **||:** F6-cook

### T-305 — Cook Mode telemetry event
- **Scope:** Add `cookModeStarted(recipeID: Int)` case to the sealed `AnalyticsEvent` enum. Wire send-site in `CookModeViewModel` to fire exactly once per recipe per session. Unit test asserts single-fire + no raw text in payload.
- **Files:** `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift`, `Packages/DODAnalytics/Tests/DODAnalyticsTests/AnalyticsEventTests.swift`, `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeViewModel.swift` (send-site).
- **AC:** AC-7.7; constitution §9 allowlist updated in the consultant pass already.
- **Deps:** T-304.
- **Est:** 1h
- **||:** F6-cook

---

### Cluster: Comments & Ratings (US-13/14/15) || F7-comments

The five-PR cluster that shipped comments + ratings via WP REST +
WPRM, with Keychain-backed guest identity (no accounts). Wave-1
(T-210..T-213) ran four worktree subagents in parallel, then
Wave-2 (T-220) integrated everything into `RecipeDetailView`.

### T-210 — Spec amendment: US-13/14/15 + CL-21/22/23
- **Scope:** Constitution + spec amendment authorizing comments, ratings, and the guest-identity pattern. Adds US-13 (read + post WP comments), US-14 (1–5 star WPRM ratings), US-15 (Keychain-stored guest name/email — no accounts). Three CL entries with rationale. App Privacy questionnaire expanded for Contact Info: Email + User Content: Customer Support.
- **Files:** `specs/dod-ios-app/spec.md`, `specs/dod-ios-app/clarifications.md`, `specs/constitution.md`, `Marketing/AppPrivacy.md`, `Marketing/TestFlight.md`, `README.md`.
- **AC:** Spec contains AC-13.* / AC-14.* / AC-15.* with REG-13 / REG-14 / REG-15 invariants. App Privacy doc reflects the new data categories.
- **Deps:** none.
- **Est:** 2h
- **Shipped:** commit `aa4340a` (`docs(spec): authorize comments + ratings`).

### T-211 — Domain + Networking: WP comments + WPRM ratings clients
- **Scope:** New domain types `RecipeComment` (Sendable+Hashable+Codable; status enum with `.unknown` fallback) and `RecipeRating` (clamped average 0…5, count ≥ 0). New `WPCommentsClient` (paged GET with `_embed=author` + headers-sourced totals, POST with optional WPRM rating meta) and `WPRMRatingsClient` (dual wrapped/flat decode, degrades to zero-summary on 401/403/offline per REG-14). New `WPDTO.Comment` / `WPDTO.CommentMeta` / `WPDTO.WPRMRatingResponse`. Golden fixtures captured 2026-05-24 from dutchovendaddy.com.
- **Files:** `Packages/DODDomain/Sources/DODDomain/RecipeComment.swift`, `Packages/DODDomain/Sources/DODDomain/RecipeRating.swift`, `Packages/DODNetworking/Sources/DODNetworking/WPCommentsClient.swift`, `Packages/DODNetworking/Sources/DODNetworking/WPRMRatingsClient.swift`, `Packages/DODNetworking/Sources/DODNetworking/WPDTOs.swift` (additive), fixtures + tests under `Packages/DODNetworking/Tests/`.
- **AC:** 23 new unit tests (11 comments + 12 ratings) green; 2 DOD_RUN_LIVE_TESTS-gated integration tests for the live blog.
- **Deps:** T-210.
- **Est:** 4h
- **Shipped:** commit `53ed8f4` (`feat(network): WP comments + WPRM ratings clients with golden fixtures`).
- **||:** F7-comments

### T-212 — Persistence: Schema V3 + Keychain guest identity
- **Scope:** New SwiftData models `CachedComment` + `CachedRating` (snapshot value types kept independent of `DODDomain` types to break merge-order dependency). New `SchemaV3` + `RecipeStore+CommentsRatings.swift` extension methods for cache + read + invalidate. New `GuestIdentityStoring` protocol with production `KeychainGuestIdentityStore` (delete-then-add per field; thread-safe SecItem calls) and test-side `InMemoryGuestIdentityStore`.
- **Files:** `Packages/DODPersistence/Sources/DODPersistence/CachedComment.swift`, `Packages/DODPersistence/Sources/DODPersistence/CachedRating.swift`, `Packages/DODPersistence/Sources/DODPersistence/SchemaV3.swift`, `Packages/DODPersistence/Sources/DODPersistence/RecipeStore+CommentsRatings.swift`, `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (additive), `Packages/DODPersistence/Sources/DODPersistence/SchemaV1.swift`, `Packages/DODPersistence/MIGRATION.md`, `Packages/DODSupport/Sources/DODSupport/GuestIdentityStore.swift`, tests under each.
- **AC:** 15 new cache tests + 7 new GuestIdentityStore tests green; SchemaV1 → V3 migration covered.
- **Deps:** T-210.
- **Est:** 5h
- **Shipped:** commit `a4a4daf` (`feat(persist): Schema V3 — CachedComment + CachedRating + Keychain GuestIdentityStore`).
- **||:** F7-comments

### T-213 — DesignSystem: ratings + comments primitives
- **Scope:** Five new SwiftUI components — `StarRating` (display + interactive), `CommentRow` (author / date / body / optional rating / pending pill), `CommentComposer` (sheet-style submit form with character counter), `GuestIdentitySheet` (non-dismissible name + email collection), `ModerationBadge` (pill for awaitingApproval / posted / failed). Pure presentation; no business logic, network, or Keychain.
- **Files:** five new files in `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/`, snapshot tests appended to `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift`, 12 PNG baselines under `__Snapshots__/`.
- **AC:** 12 new snapshot tests pass on iOS Simulator (recorded baselines committed).
- **Deps:** T-210.
- **Est:** 3h
- **Shipped:** commit `9cae2b1` (`feat(design): StarRating + CommentRow + CommentComposer + GuestIdentitySheet`).
- **||:** F7-comments

### T-220 — RecipeDetail integration
- **Scope:** Wire the components + clients + cache into `RecipeDetailView`. New `RecipeDetailRatingsSection`, expanded `RecipeDetailViewModel` (`loadRatingsAndComments`, `submitRating`, `submitComment`, `saveGuestIdentityAndContinue`, identity gating, hung-fetch non-blocking), expanded `RecipeDetailDependencies` + `LiveRecipeDetailDependencies` (rating summary fetch with REG-14 graceful zero, paged comments, snapshot ↔ domain bridging). New `AnalyticsEvent.recipeRated(recipeID:stars:)` + `recipeCommentSubmitted(recipeID:awaitingApproval:)`. `AppDependencies` constructs `WPCommentsClient`, `WPRMRatingsClient`, `KeychainGuestIdentityStore` and passes them through. XCUI smoke test asserts the "Ratings & Reviews" header renders.
- **Files:** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailRatingsSection.swift` (new), `RecipeDetailDependencies.swift`, `RecipeDetailViewModel.swift`, `RecipeDetailView.swift`, `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift`, `App/AppDependencies.swift`, `UITests/RecipeDetailRatingsSmokeTests.swift` (new). Follow-up `9a161a0` extracted `FakeRecipeDetailDependencies` to a separate file and added 8 regression tests + 3 snapshot baselines after the iOS-Sim build surfaced SwiftLint failures that the SPM `swift test` slice missed.
- **AC:** DODAnalytics 12 tests + DODFeatureRecipeDetail 45 tests green; iOS-Sim app build succeeds; XCUI smoke test asserts the section renders.
- **Deps:** T-211, T-212, T-213.
- **Est:** 4h (+1h for the SwiftLint+format regression catch in `9a161a0`)
- **Shipped:** commits `056f096` (feature) + `9a161a0` (lint/format/regression coverage).
- **||:** F7-comments

---

## Phase 8 — Post-launch polish cluster (2026-05-24)

Parallelism tag conventions: tasks sharing `||:` letter can run simultaneously in separate worktrees. Tasks within US-17 (`P8-widget-*`) are sequenced because they touch related files; tasks across stories (`P8-tab`, `P8-widget-*`, `P8-darkmode`) are independent.

### T-310 — Tab bar refinement (US-16)
- **Scope:** Reorder `AppTab.allCases` to **Recipes → Categories → Saved → Search**. Change `AppTab.systemImage` for `.saved` from `"heart"` to `"bookmark"`. Selection-fill behavior (`bookmark.fill` when selected) handled by SwiftUI's default tab styling. Tests: an enum-level unit test pinning `AppTab.allCases` order; an L3 smoke test asserting the third tab opens Saved; updated L4 snapshots of the tab bar in light + dark, iPhone + iPad, with each tab selected.
- **Files:** `App/AppTab.swift`, `App/AppTabTests.swift` (new, in `UITests/` if there isn't a host target — confirm at implementation time), `UITests/DODAppUITests/SmokeTests.swift` (extend), snapshot baselines under the appropriate `__Snapshots__` folder.
- **AC:** AC-16.1, AC-16.2, AC-16.3, AC-16.4, AC-16.5, AC-16.6.
- **Deps:** —
- **Est:** 1h
- **||:** P8-tab

### T-320 — SavedRecipesWidget snapshot infrastructure (US-17)
- **Scope:** New `SavedRecipesWidgetSnapshot` struct in `Packages/DODSupport/Sources/DODSupport/` (next to existing `WidgetSnapshot.swift`). Codable, versioned (`schemaVersion: 1`). Writer extends `WidgetSnapshotStore` with a saved-recipes file inside the App Group container. Unit tests: round-trip, max-entries cap (small=1 / medium=3), version-mismatch rejection, clear-on-empty.
- **Files:** New `Packages/DODSupport/Sources/DODSupport/SavedRecipesWidgetSnapshot.swift`, update to `Packages/DODSupport/Sources/DODSupport/WidgetSnapshotStore.swift` (add saved file path + writer method), new `Packages/DODSupport/Tests/DODSupportTests/SavedRecipesWidgetSnapshotTests.swift`.
- **AC:** AC-17.3, AC-17.6 (snapshot side), AC-17.8 (L1 cases).
- **Deps:** — (independent of T-310, T-330; pairs with T-321 + T-322 inside the widget cluster).
- **Est:** 2h
- **||:** P8-widget-snapshot

### T-321 — SavedRecipesWidget extension + entry view (US-17)
- **Scope:** New `SavedRecipesWidget` widget kind in `Widget/` (next to `FeaturedRecipeWidget.swift`). Timeline provider reads `SavedRecipesWidgetSnapshot` from the App Group; renders small (1 recipe) + medium (3 recipes). Reuses `WidgetCard` from `DODDesignSystem` (extend if the saved-recipes row shape differs meaningfully — prefer a variant over a new component). Empty state with placeholder text + `dod://saved` tap target. Register in `DODAppWidgetBundle`. Add `dod://saved` parse case to `WidgetDeepLinkParser`. L4 snapshot tests for empty / 1-saved / 3-saved on both sizes, both appearances.
- **Files:** New `Widget/SavedRecipesWidget.swift`, new `Widget/SavedRecipesWidgetEntryView.swift`, update `Widget/DODAppWidgetBundle.swift`, update `Packages/DODSupport/Sources/DODSupport/WidgetDeepLinkParser.swift` + tests, update `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` if a variant is needed (with snapshot tests for it).
- **AC:** AC-17.1, AC-17.2, AC-17.4, AC-17.5, AC-17.7, AC-17.8 (deep-link case).
- **Deps:** T-320 (consumes the snapshot type), T-310 (Saved tab position — `dod://saved` lands on whichever tab index Saved occupies after T-310 merges).
- **Est:** 3h
- **||:** P8-widget-ext

### T-322 — SavedStore observation + snapshot writer wiring (US-17)
- **Scope:** Observe `SavedStore` from `DODApp` (or `AppDependencies` startup). On every saved-set mutation, build the small + medium snapshot payloads, write them via the `WidgetSnapshotStore` API from T-320, and call `WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")`. Cap payload at the medium size's 3 entries (writing more is wasted I/O). Unit test asserts: writer called on save, writer called on unsave, payload contents are the N most-recently-saved sorted by `savedAt` desc.
- **Files:** `App/DODApp.swift` or `App/AppDependencies.swift` (observation setup), new unit test in the appropriate package — likely a new helper in `Packages/DODPersistence/` or a host-test if the observation glue is App-target-only.
- **AC:** AC-17.3 (host side), AC-17.6 (reload trigger).
- **Deps:** T-320, T-321 (the widget must exist before its timeline reloads do anything useful, but the writer can land before the widget — keep the merge order T-320 → T-321 → T-322).
- **Est:** 2h
- **||:** P8-widget-host

### T-323 — `widgetOpened` analytics event (US-17)
- **Scope:** Replace the implicit widget-deep-link consumption logging with a single `widgetOpened(kind: WidgetKind, recipeID: Int?)` `AnalyticsEvent` case where `WidgetKind = .featured | .saved`. Update the existing featured-widget tap site to fire it; add the saved-widget tap site. Constitution §9 allowlist gets the new event. Unit test asserts payload shape (no free text, integer or nil recipeID only).
- **Files:** `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift`, `Packages/DODAnalytics/Tests/DODAnalyticsTests/AnalyticsEventTests.swift`, the existing featured-widget tap consumer (probably `App/RootView.swift` or `App/DeepLinkDispatcher.swift`), constitution §9 allowlist amendment.
- **AC:** AC-17.9.
- **Deps:** T-321 (saved tap site exists).
- **Est:** 1h
- **||:** P8-widget-tel

### T-330 — Appearance audit (US-18)
- **Scope:** **Audit phase only.** Walk every top-level screen and every `DODDesignSystem/Components/` component in both light and dark appearance, default + AX5 Dynamic Type. Fill any missing L4 snapshot baselines (one PR per gap class, not one PR per missing baseline — pragmatic). Produce `specs/dod-ios-app/appearance-audit.md` with the surface × appearance × Dynamic Type matrix, each cell marked pass/fail/n/a with a one-line note. **Any fix surfaced by the audit is logged as a T-331..T-339 follow-up task in this same file**; T-330 itself doesn't ship fixes, only the audit + missing baselines.
- **Files:** New `specs/dod-ios-app/appearance-audit.md`, new L4 snapshot files in the appropriate packages, follow-up task entries below the summary.
- **AC:** AC-18.1, AC-18.2, AC-18.3, AC-18.6.
- **Deps:** — (independent; runs against current main).
- **Est:** 4h (audit + baseline fills)
- **||:** P8-darkmode

### T-331 — Commit dark + AX5 baselines for DesignSystem (US-18 follow-up)
- **Scope:** Run `xcodebuild test -scheme DODDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17'` against the 20 new `*_dark` / `*_AX5` test methods T-330 added in `SnapshotTests+AppearanceAudit.swift`. The tests already use `record: .missing`, so the first run lays the PNGs down automatically. Open each one; if it looks right, commit it under `__Snapshots__/DesignSystemAppearanceSnapshotTests/`. Pure baseline harvest — no source changes to the component implementations or the test file itself (T-330 already extended the test surface; this task only commits the resulting baselines). No contrast bug is expected; if one surfaces, log a separate T-33x for the fix.
- **Files:** `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/DesignSystemAppearanceSnapshotTests/test_*_dark.1.png`, `test_*_AX5.1.png` (20 new PNGs).
- **AC:** AC-18.1, AC-18.2, AC-18.4 (verify each rendered baseline).
- **Deps:** T-330.
- **Est:** 1h (sim run + spot-check + commit).
- **||:** P8-darkmode
- **Shipped:** commit `57c4e03` (`chore(T-331): record DesignSystem dark + AX5 snapshot baselines (US-18)`). Recorded against Xcode 26.5 / iOS 26.5 / iPhone 17 simulator. 21 PNGs landed (17 dark + 4 AX5 — the original task estimate of 20 was off by one) under `__Snapshots__/SnapshotTests+AppearanceAudit/` (lib derives the directory from the source-file basename, not the test class name).

### T-332 — Top-level screen snapshot tests (US-18 follow-up)
- **Scope:** Stand up new snapshot test files for the five top-level screens that lack any visual coverage: Feed, Categories list, Category detail, Search, Saved. Each test file lives next to the existing `*ViewModelTests.swift` in its feature package. Coverage: 1 representative state per screen (e.g. Feed = loaded with 6 rows; Saved = 3 saved) × {light, dark} × {defT, AX5} = 4 snapshots per screen, ~20 PNGs total. Requires adding `swift-snapshot-testing` to `Package.swift` for `DODFeatureFeed`, `DODFeatureCategories`, `DODFeatureSaved`, `DODFeatureSearch` (currently only `DODDesignSystem` and `DODFeatureRecipeDetail` declare the dep). Plus a `StatefulHost`-style shim per screen so the `*ViewModel` can be put into the desired state synchronously without going through real dependencies.
- **Files:** `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/FeedViewSnapshotTests.swift`, `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/CategoryListViewSnapshotTests.swift` + `CategoryRecipesViewSnapshotTests.swift`, `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/SavedViewSnapshotTests.swift`, `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/SearchViewSnapshotTests.swift`, plus `Package.swift` amendments in each. New `__Snapshots__` directories with the resulting PNGs.
- **AC:** AC-18.1, AC-18.4.
- **Deps:** T-330.
- **Est:** 4h (test infrastructure + sim record + visual review).
- **||:** P8-darkmode
- **Shipped:** commit `44ce7b9` — 5 new snapshot test files (Feed, CategoryList, CategoryRecipes, Search, Saved) with 4 test methods each = 20 total; `swift-snapshot-testing` 1.17.0 added to the 4 feature `Package.swift` files; `StatefulHost` shim per test file (test-target-only, never in production target); `record: .missing` so baselines lay down on first iOS-sim run. PNGs not committed by this PR — see T-335.

### T-333 — Commit Cook Live Activity baselines (US-18 follow-up)
- **Scope:** The existing `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/CookLiveActivitySnapshotTests.swift` declares five tests but commits no PNGs — running them today fails. Record mode pass to lay down the five baselines; extend the lock-screen test with a `_dark` variant. The Dynamic Island compact pieces are tiny system-controlled surfaces — light-only is sufficient (system inverts them automatically). Recipe detail root view dark + AX5 also handled here.
- **Files:** New PNGs under `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/__Snapshots__/CookLiveActivitySnapshotTests/`, plus extension of `CookLiveActivitySnapshotTests.swift` with `_dark` lock-screen variant. Optional: new `RecipeDetailViewSnapshotTests.swift` for the recipe detail root view dark + AX5 cell.
- **AC:** AC-18.1.
- **Deps:** T-330.
- **Est:** 2h.
- **||:** P8-darkmode

### T-334 — Tab bar appearance baseline (US-18 + US-16 follow-up)
- **Scope:** Once the US-16 tab bar refinement (T-310) lands, snapshot the assembled `TabStack` in both appearances at default Dynamic Type. Single light + single dark PNG is enough — the tab bar is system chrome plus an icon set; AX5 is not meaningful (tab bar text never scales beyond the system cap). Lives next to whatever test target ends up housing `TabStack`.
- **Files:** TBD pending T-310's choice of test target; likely a new `App/Tests/TabStackSnapshotTests.swift` or a host-app L4 test.
- **AC:** AC-18.1, AC-16.x (the relevant US-16 visual criterion).
- **Deps:** T-330, T-310.
- **Est:** 1h.
- **||:** P8-darkmode

### T-335 — Harvest + commit T-332's screen baselines (US-18 follow-up)
- **Scope:** T-332 added 20 new snapshot test methods across four feature packages (`DODFeatureFeed`, `DODFeatureCategories`, `DODFeatureSearch`, `DODFeatureSaved`) but committed no PNGs — the tests use `record: .missing`, so the first iOS-sim run lays the baselines down. Sim record pass: run `xcodebuild test -scheme <each>` for each of the four packages on `platform=iOS Simulator,name=iPhone 17`, open every resulting PNG, and commit it under the matching `__Snapshots__/<TestClass>/` directory if it looks correct. Pure baseline harvest — no source changes to the views, view-models, or test files themselves (T-332 already extended the test surface; this task only commits the resulting baselines). Mirrors the T-330 → T-331 relationship for DesignSystem.
- **Files:** `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/__Snapshots__/FeedViewSnapshotTests/test_loadedFeed_*.1.png` (×4), `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/__Snapshots__/CategoryListViewSnapshotTests/test_loadedCategories_*.1.png` (×4) + `__Snapshots__/CategoryRecipesViewSnapshotTests/test_loadedRecipes_*.1.png` (×4), `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/__Snapshots__/SearchViewSnapshotTests/test_searchResults_*.1.png` (×4), `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/__Snapshots__/SavedViewSnapshotTests/test_loadedSaved_*.1.png` (×4) — 20 PNGs total.
- **AC:** AC-18.1, AC-18.4 (verify each rendered baseline).
- **Deps:** T-332.
- **Est:** 1h (sim run + spot-check + commit).
- **||:** P8-darkmode

---

## Phase 9 — Categories modernization (2026-05-24)

Single-task cluster for US-19 / CL-31..33. Layout-pass over `CategoryListView`, no DesignSystem token churn, no touch on US-2's data contract.

### T-340 — Categories tab visual modernization (US-19)
- **Scope:** Restyle `CategoryListView` to use SwiftUI's `.insetGrouped` list with system disclosure rows, secondary-label trailing count, and a `.searchable`-backed name filter. Replace the hand-rolled `Button { } label: { HStack { … Image(systemName: "chevron.right") } }` with an iOS-stock cell shape. No `CategoryRecipesView` changes; no token edits in `DODDesignSystem`. Tests: re-record the four existing `CategoryListViewSnapshotTests` baselines (light/dark × default/AX5 on iPhone 13) to lock the new look, add two new iPad-12.9" baselines (light + dark, default Dynamic Type) per AC-19.5, and add a `CategoryListViewModelTests` (or extension thereof) unit test asserting the new client-side search filter works case-insensitively and that an empty/whitespace query restores the full list. AC-2.1..AC-2.5 stay green via the existing `CategoryListViewModelTests` suite — no test rewrite, just confirm the suite still passes against the new view.
- **Files:** `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift` (layout + `.searchable`), `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/CategoryListViewSnapshotTests.swift` (extend with iPad-12.9" tests, re-record baselines), `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/CategoriesTests.swift` (search-filter unit test). Snapshot PNGs under `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/__Snapshots__/CategoryListViewSnapshotTests/`. **Out of bounds:** `Packages/DODDesignSystem/**`, `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryRecipesView.swift` (CategoryRecipes grid is governed by US-2 AC-2.3 and was already modernized by T-300 / CC-9), `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListViewModel.swift` (no data-shape changes required for a pure visual pass).
- **AC:** AC-19.1, AC-19.2, AC-19.3, AC-19.4, AC-19.5, AC-19.6; pins AC-2.1..AC-2.5.
- **Deps:** — (independent; runs against current main).
- **Est:** 2h
- **||:** P9-categories

---

## Phase 10 — Search + widget polish (2026-05-24)

Cluster for small visual / iconography fixes the backlog flagged after Phase 9 closed. Items here are single-PR scoped and mostly independent — they share a phase so the file structure stays readable as the post-launch polish list grows. T-360 + T-361 form an internal sub-cluster (latest-recipe widget + image bridge); other entries are standalone.

### T-380 — Heart → bookmark in saved-recipes surfaces (CL-38, amends AC-16.3)
- **Scope:** Sweep every `Image(systemName: "heart")` / `"heart.fill"` and "heart" copy string in the saved-recipes context to `"bookmark"` / `"bookmark.fill"` / "bookmark". Touches: `RecipeDetailView` nav-bar Save button (`AC-4.7`), `RecipeDetailFloatingActions` sticky Save button (T-302's variant of the same affordance, also `AC-4.7`), `SavedView` empty state (`AC-5.8` icon + copy), `OnboardingSheet` welcome bullet (`AC-8.1` copy + glyph, plus the in-file `#Preview` and the test fixture in `SnapshotTests+AppearanceAudit`), `RootView.welcomeBullets` (the production source of those bullets), `RecipeAppIntents.DODShortcuts` (`OpenSavedRecipesIntent` `systemImageName` per `AC-10.4`), `EmptyState.swift` `#Preview` doc-fixture, `SnapshotTests` test fixture (matches the production copy), comment / doc-string scrubs in `AppTab.swift`, `AnalyticsEvent.swift` (`recipeSaved` / `recipeUnsaved` doc comments), `Colors.swift` (accent comment), `AppTabTests.swift` (comment about the in-recipe heart now superseded), plus the `accessibility-audit.md` "Save heart button" row, the `plan.md` "Heart toggle" + accent-color comments, the `Marketing/AppStoreCopy.md` "tap the heart" line, and the `Marketing/Screenshots/README.md` "heart-filled state" note. **Snapshot baseline re-record:** every L4 baseline that renders a save button or an EmptyState heart (DesignSystem `test_emptyState_default*`, `test_onboardingSheet_default*`, plus any RecipeDetail / Saved baseline once the new glyph is in place). **Visually review each PNG before commit.** **Out of bounds:** the wire-format string `WidgetKind.saved` in `AnalyticsEvent.widgetOpened` (internal — not user-facing copy); Live Activity Cook Mode glyphs (US-11 territory); other tab icons; brand-token names like `castIronBrown` / `burntOrange`.
- **Files:** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift`, `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailFloatingActions.swift`, `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift`, `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/EmptyState.swift`, `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/OnboardingSheet.swift`, `App/RootView.swift`, `App/RecipeAppIntents.swift`, `App/AppTab.swift`, `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift`, `Packages/DODDesignSystem/Sources/DODDesignSystem/Colors.swift`, `AppTests/AppTabTests.swift`, `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift`, `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests+AppearanceAudit.swift`, `specs/dod-ios-app/accessibility-audit.md`, `specs/dod-ios-app/plan.md`, `Marketing/AppStoreCopy.md`, `Marketing/Screenshots/README.md`, plus the re-recorded L4 baselines under each touched test target's `__Snapshots__/`.
- **AC:** Implements amended AC-4.7, AC-5.1, AC-5.8, AC-8.1, AC-16.3 (all amended by CL-38); pins AC-10.4 (Siri shortcut glyph stays consistent with the in-app glyph).
- **Deps:** — (independent; runs against current main; assumes T-310 already shipped the tab-icon half of CL-24).
- **Est:** 2h (sweep is small; visual review of every re-recorded snapshot is what makes it M-shaped per the backlog estimate).
- **||:** P10-glyph

### T-350 — Search filter chip iconography (US-20)
- **Scope:** Pure SF Symbol swap on the Search tab's two category-flavored surfaces. (1) `FilterChipRow.categoryChip` `systemImage` argument: `"folder"` → `"tag.fill"` so the chip glyph reads as "filter by taxonomy" instead of "navigate into a folder" (CL-34). (2) `IdleSuggestionsView`'s "Try" section pill builder call site: `pill(text: category.name, systemImage: "folder")` → `pill(text: category.name, systemImage: "tag.fill")` so the idle-state category suggestions match the filter chip glyph. The `.noResults` `EmptyState` `questionmark.folder` glyph is explicitly **not** touched per AC-20.3 — it denotes a search-not-found state, not a category filter. No layout change, no token change, no view-model change; the surrounding chip text, menu contents, `isOn` selected-state fill, accessibility labels, and pill action handlers are byte-for-byte preserved. Tests: add `FilterChipRowSnapshotTests` with 4 chip-only PNG baselines (selected + unselected × light + dark, default Dynamic Type, iPhone 13 baseline). Existing `SearchViewSnapshotTests` baselines remain owned by T-335 — those PNGs are **not** committed by this PR (mirrors the T-340 / CategoryRecipesView precedent where a sim-recorded PNG outside the task's deliverable was left untracked).
- **Files:** `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (two `systemImage` string literal edits), `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/FilterChipRowSnapshotTests.swift` (new — 4 test methods + a `FilterChipRowHost` SwiftUI shim that holds the `@State` binding for the chip row outside of the wider `SearchView`). Snapshot PNGs under `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/__Snapshots__/FilterChipRowSnapshotTests/`. **Out of bounds:** `SearchView.swift` line ~74 `questionmark.folder` empty-state glyph (per AC-20.3), `SearchViewModel.swift`, `SearchFilters.swift`, `SearchResultMerger.swift`, `RecentSearches.swift` (no logic change), `SearchViewSnapshotTests.swift` and its baselines (owned by T-335).
- **AC:** AC-20.1, AC-20.2, AC-20.3, AC-20.4, AC-20.5; pins AC-12.1..AC-12.6.
- **Deps:** — (independent; runs against current main).
- **Est:** 1h
- **||:** P10-search

### T-360 — Latest Recipe widget: rename + real hero image (US-21)
- **Scope:** Two changes to the existing US-9 featured widget, plus a shared image bridge that both widgets can later consume.
  1. **Rename.** `FeaturedRecipeWidget.configurationDisplayName(_:)` "Today's Recipe" → "Latest Recipe" (AC-21.1).
  2. **Image bridge (CL-35).** New `WidgetImageBridge` helper in `DODSupport` exposing a deterministic filename for a given image URL (`SHA256(urlString) + ".jpg"`) and a `containerURL(forSecurityApplicationGroupIdentifier:)`-backed file URL resolver. The bridge is a pure library — no I/O methods beyond reading. Writes happen inside `RecipeStore.cacheImage(url:bytes:...)`: after the SwiftData insert/update, write the same bytes to the App Group container at the deterministic filename. Eviction inside `RecipeStore.evictImagesIfNeeded()` deletes the corresponding file alongside the SwiftData row (AC-21.4). Both file write and file delete are best-effort — they log on failure but never throw past SwiftData.
  3. **Snapshot wire format.** `WidgetSnapshot.Entry` gains an additive optional `heroImageFilename: String?` field. Existing readers (any out-of-date widget binary against a new host payload) ignore unknown fields. The version tag bumps so older host binaries against a new widget read the snapshot as version-mismatched and fall back to the placeholder — same contract as today.
  4. **Snapshot writer.** `LiveFeedDependencies.publishWidgetSnapshot(items:)` computes the filename for each `RecipeListItem`'s `heroImage` URL via `WidgetImageBridge.filename(for:)` and populates the new field. The filename is populated whether or not the file currently exists on disk — the widget reads the file by name and falls back to the placeholder gradient if absent (AC-21.3). This keeps the snapshot writer pure (no I/O dependency).
  5. **Widget render.** `FeaturedRecipeWidgetEntryView` resolves `entry.recipe.heroImageFilename` into a `file://` URL via `WidgetImageBridge.fileURL(forFilename:)` and passes it to the existing `WidgetCard.Content.heroImageURL`. The render path inside `WidgetCard.Hero` is unchanged — `AsyncImage` against a `file://` URL is a local read (AC-21.3, no widget-side network). Existing snapshot baselines for `WidgetCard.Small/Medium` with `heroImageURL: nil` are unaffected (the empty case still renders the gradient placeholder).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-21), `specs/dod-ios-app/clarifications.md` (CL-35, CL-36), `specs/dod-ios-app/tasks.md` (this entry + T-361), `specs/dod-ios-app/backlog.md` (graduation).
  - **Source (commit 2):** `Packages/DODSupport/Sources/DODSupport/WidgetImageBridge.swift` (new, ~50 LOC); `Packages/DODSupport/Sources/DODSupport/WidgetSnapshot.swift` (add `heroImageFilename` to `Entry`, no other shape change); `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (file write on cache, file delete on evict); `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedDependencies.swift` (snapshot writer populates filename); `Widget/FeaturedRecipeWidget.swift` (display name); `Widget/FeaturedRecipeWidgetEntryView.swift` (filename → file URL).
  - **Tests (commit 2):** `Packages/DODSupport/Tests/DODSupportTests/WidgetImageBridgeTests.swift` (new); `Packages/DODSupport/Tests/DODSupportTests/WidgetSnapshotTests.swift` (additive — round-trip with the new filename field); `Packages/DODPersistence/Tests/DODPersistenceTests/RecipeStoreTests.swift` (extend — assert cache writes a file, evict removes it); `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift` (re-record the populated-with-image baselines using a fixture image; placeholder baseline unaffected).
  - **Out of bounds:** `Widget/SavedRecipesWidget.swift` and its entry view + `SavedRecipesWidgetPublisher.swift` — saved-widget consumption is T-361's deliverable (the bridge is built here, just not wired on that surface). Lock-screen widget code (T-370, parallel branch `feat/T-370-lock-screen-widget`) — lock-screen widgets are text-only and don't need the bridge.
- **AC:** AC-21.1, AC-21.2, AC-21.3, AC-21.4, AC-21.5, AC-21.6; pins AC-9.1..AC-9.4 (US-9), AC-17.6 (US-17 widget-side no-network contract).
- **Deps:** — (independent; runs against current main).
- **Est:** 4h
- **||:** P10-latest-widget

### T-361 — Saved-recipes widget: consume image bridge (US-21 follow-up, US-17 polish)
- **Scope:** Wire `SavedRecipesWidgetPublisher.toSnapshotEntry(_:)` to populate `heroImageFilename` via `WidgetImageBridge.filename(for:)` instead of always passing nil. Reads `SavedRecipeWidgetRow.heroImageURL` (already plumbed through T-322); no changes to `RecipeStore.savedRecipesForWidget(limit:)` shape. Widget extension already resolves filenames per `SavedRecipesWidgetEntryView.heroImageURL(forFilename:)` (T-321) — no widget-side change. L4 snapshot baselines for `WidgetCard.Saved*` populated states re-recorded against the real-image render path (T-360's fixture image works here too). Updates the explicit "Future work" comment in `SavedRecipesWidgetPublisher.toSnapshotEntry(_:)` to point at the bridge instead of trailing as an open TODO.
- **Files:** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/SavedRecipesWidgetPublisher.swift` (filename now non-nil), `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/SavedRecipesWidgetPublisherTests.swift` (extend to assert the bridged filename matches the URL), `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SavedWidgetSnapshotTests.swift` (re-record populated baselines), corresponding PNGs under `__Snapshots__/SavedWidgetSnapshotTests/`.
- **AC:** AC-17.3 (host side, filename now honest), AC-21.2 (bridge is the single writer; saved widget is the second consumer).
- **Deps:** T-360 (consumes `WidgetImageBridge` which T-360 introduces).
- **Est:** 1.5h
- **||:** P10-latest-widget

### T-362 — Featured widget hero image bridge: feed-side prefetch (REG-T-360)
- **Scope:** Fix REG-T-360. T-360 built `WidgetImageBridge` and wired `RecipeStore.cacheImage(url:bytes:)` to mirror bytes into the App Group container — but the feed-load path never calls `cacheImage(...)` for hero images (the only production caller is `LiveSavedDependencies.preDownloadImages` for AC-5.2 saved-recipe pre-download). As a result, the widget snapshot's `heroImageFilename` strings point at files that never exist, and the featured widget always falls back to the gradient placeholder. CL-45 captures the root cause + the fix shape. **Change:** `LiveFeedDependencies` gains a `LiveFeedDependencies.ImagePrefetcher` typealias (a `Sendable` closure that takes a `[URL]` and a recipe-store handle), constructed in the App composition root from the existing `ImageLoader` + `RecipeStore` singletons. `publishWidgetSnapshot(items:)` calls the prefetcher in a detached `Task { ... }` **after** the snapshot has been written, so feed-load latency is unaffected. The prefetcher iterates the same trimmed `WidgetSnapshotConfig.maxEntries` slice that was just snapshotted, awaits `ImageLoader.data(for: url)` per `heroImage`, and routes the bytes through `RecipeStore.cacheImage(url:bytes:)` — which writes both the SwiftData row and (via the existing bridge hook) the App Group file. Per-URL failures are logged + swallowed; one bad URL never blocks the rest. Adds `DODLog.persistence.debug(...)` inside `RecipeStore.cacheImage(url:bytes:)` and inside `WidgetImageBridge.writeImage(bytes:for:)` so future regressions of this exact shape (filename in snapshot but no file on disk) surface in `Console.app` rather than requiring a backlog round-trip. One new regression test in `LiveFeedDependenciesImageBridgeTests.swift` constructs a `LiveFeedDependencies` with a counting `ImagePrefetcher` stub, calls `publishWidgetSnapshot(items:)` with two items, and asserts the stub was invoked with the two URLs (proves the call site fires; the live `cacheImage` + `WidgetImageBridge.writeImage` paths are already covered by their own existing tests at `RecipeStoreTests.swift` and `WidgetImageBridgeTests.swift`).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/clarifications.md` (CL-45), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate REG-T-360).
  - **Source (commit 2):** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedDependencies.swift` (add `ImagePrefetcher` typealias, accept it in `init`, kick off the fire-and-forget `Task` at the end of `publishWidgetSnapshot(items:)`); `App/AppDependencies.swift` (construct the prefetcher closure from `imageLoader` + `store` and pass it into `LiveFeedDependencies`); `Packages/DODPersistence/Sources/DODPersistence/RecipeStore+ImageCache.swift` (one `DODLog.persistence.debug(...)` line at the start of `cacheImage(...)`); `Packages/DODSupport/Sources/DODSupport/WidgetImageBridge.swift` (one `DODLog.persistence.debug(...)` line inside `writeImage(bytes:for:)` on the success branch).
  - **Tests (commit 2):** new `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/LiveFeedDependenciesImageBridgeTests.swift` (asserts `ImagePrefetcher` is invoked with the snapshot URLs).
  - **Out of bounds:** any change to `WidgetImageBridge.filename(for:)` (deterministic SHA256 — locked by T-360 + its tests), any change to the snapshot wire format (`WidgetSnapshot.Entry.heroImageFilename` is locked by CL-35 + T-360), any change to `evictImagesIfNeeded` (eviction parity is locked by T-360 + its tests), any change to `LiveSavedDependencies.preDownloadImages` (separate AC-5.2 surface, unaffected), any snapshot-baseline re-record (the rendered widget face doesn't change — only the file-write call site does).
- **AC:** AC-21.2 (bridge writes for every cached image — now actually fires for feed entries too), AC-21.3 (widget reads bridged filenames — once the files exist, the existing path resolves them).
- **Deps:** T-360 (built the bridge this PR makes effective).
- **Est:** 1.5h
- **||:** P10-latest-widget

### T-370 — Lock-screen widget for Latest Recipe (US-22)
- **Scope:** Add a third widget kind, `LatestRecipeLockScreenWidget`, to `DODAppWidgetBundle` after `FeaturedRecipeWidget` and `SavedRecipesWidget`. The widget exposes `.accessoryRectangular` only (CL-37 spells out why `.accessoryCircular` and `.accessoryInline` are out of scope). The `TimelineProvider` reuses the existing `WidgetSnapshotStore.read()` and reads the same key the home-screen widget reads — no new snapshot file, no new App Group key, no new host-side observer. Tap target on populated state is `dod://recipe/<id>` (existing US-9 parser case); on empty state, `dod://feed` (also existing). The entry view renders text-only: title (1–2 lines, truncated) over a one-line short description. No image rendering — lock-screen widgets are monochrome by design and `WidgetCard.Hero` doesn't apply. A new `LockScreenWidgetSnapshotTests.swift` file in `DODDesignSystem/Tests/` covers L4 baselines for populated / populated-with-long-title / empty states under the system `.accessoryRectangular` frame; lives in its own file alongside `SavedWidgetSnapshotTests.swift` to keep `SnapshotTests.swift` under SwiftLint's 400-line file-length warning cap. No `WidgetDeepLinkParser` changes (existing `dod://recipe/<id>` + `dod://feed` cover the lock-screen widget's tap-target needs). No `widgetOpened` analytics changes — if we want to track lock-screen taps in a future story, that's a fresh CL adding `.lockScreen` (or similar) as a `WidgetKind` case (see T-323 / AC-17.9 for the existing event shape).
- **Files:** New `Widget/LatestRecipeLockScreenWidget.swift` (the `Widget` declaration + `StaticConfiguration`, matching `FeaturedRecipeWidget.swift`'s shape), new `Widget/LatestRecipeLockScreenWidgetEntryView.swift` (text-only entry view with `widgetURL` tap target), update `Widget/DODAppWidgetBundle.swift` (register the new widget after the existing two), new `Widget/LatestRecipeLockScreenTimelineProvider.swift` (or fold into the widget file if it stays under 80 lines), new `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard+LockScreen.swift` (`WidgetCard.LockScreenRectangular` + `LockScreenEmpty` view primitives so the layout layer can be snapshot-tested without linking WidgetKit, mirroring the existing `WidgetCard+Saved.swift` split), new `Packages/DODDesignSystem/Tests/DODDesignSystemTests/LockScreenWidgetSnapshotTests.swift` (L4 baselines for populated / populated-long-title / empty). **Out of bounds:** home-screen widget code (`FeaturedRecipeWidget.swift`, `FeaturedRecipeWidgetEntryView.swift`, `FeaturedRecipeTimelineProvider.swift`) — that's T-360's territory (the parallel "Latest Recipe" rename + image task); the only `Widget/DODAppWidgetBundle.swift` change in this PR is the new registration line. `Packages/DODSupport/Sources/DODSupport/WidgetSnapshot.swift` (snapshot wire format unchanged — we read what's already there). `Packages/DODSupport/Sources/DODSupport/WidgetDeepLinkParser.swift` (existing URL grammar covers our needs). `Packages/DODAnalytics/**` (no `widgetOpened` shape changes).
- **AC:** AC-22.1, AC-22.2, AC-22.3, AC-22.4, AC-22.5. Locked by REG-22.
- **Deps:** — (independent; runs against current main). Coordination note: T-360 (home-screen Latest Recipe rename + image) is in parallel on `feat/T-360-latest-recipe-widget` and will conflict on `Widget/DODAppWidgetBundle.swift` (both add registrations); the later PR rebases on the first.
- **Est:** 3h
- **||:** P10-lockscreen

### T-410 — Recipe detail action cleanup: remove sticky duplicates, swap rating composer button positions (US-26)
- **Scope:** Two-part polish that amends T-302's "Phase 6 recipe-detail polish" decision and swaps the visual positions of the rating composer's action-row buttons. (1) Delete `RecipeDetailFloatingActions.swift` (the sticky bottom-trailing Save + Share row T-302 introduced) and its call site in `RecipeDetailView.body`'s `.overlay(alignment: .bottomTrailing)` modifier; remove the private `floatingActionsOverlay` `@ViewBuilder` from `RecipeDetailView`. The nav-bar Save (`AC-4.7`, bookmark glyph post-T-380) + Share (`AC-4.8`) become the single in-recipe affordance for both actions (CL-42). The save haptic (`.sensoryFeedback(.success, trigger: viewModel.isSaved)`), `viewModel.toggleSaved()`, `viewModel.didShare()`, and `viewModel.canonicalURL` are all preserved — only the duplicate UI surface is removed. (2) Swap the visual positions of the Cancel + Submit buttons in `CommentComposer.actions` so Submit (primary, `.borderedProminent`) sits at the **leading** edge and Cancel (`role: .cancel`, `.bordered`) sits at the **trailing** edge — honors the user's literal "swap" request (CL-41 documents the deviation from the iPhone-stock HIG default and walks through why the literal swap is the chosen path). The cancel role is preserved on the Cancel button so VoiceOver + the system back-gesture still treat it as the cancel affordance; the swap is purely visual. The button styles, accessibility labels, `isSubmitting` disabled state, "Submitting…" label swap, and `canSubmit` gate are byte-for-byte preserved. **Snapshot baseline re-record:** `test_commentComposer_emptyState` + `test_commentComposer_filledState` in `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift`, plus `test_commentComposer_filledState_dark` in `SnapshotTests+AppearanceAudit.swift` (the actions row layout changed). All three `RecipeDetailRatingsSection` baselines (`test_section_emptyState_renders`, `test_section_loadedState_renders`, `test_section_identityGated_rendersComposer`) in `RecipeDetailRatingsViewSnapshotTests.swift` re-record because the inline composer's button row sits at the bottom edge of every `sizeThatFits` section snapshot. **Visually review each PNG before commit.** **Out of bounds:** the inline `userRatingBar` Submit-only button in `RecipeDetailRatingsSection` (no Cancel pair — nothing to swap); the `GuestIdentitySheet` Continue/Cancel pair (separate composer, not in CL-41's scope); the `WidgetCard` Save affordance (no Save button on widgets); any change to `viewModel.toggleSaved` / `viewModel.didShare` / `viewModel.canonicalURL` behavior.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-26, amended AC-4.7 footnote pointing at CL-42), `specs/dod-ios-app/clarifications.md` (CL-41, CL-42), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduation).
  - **Source (commit 2):** delete `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailFloatingActions.swift`; edit `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` (remove the `.overlay(alignment: .bottomTrailing)` modifier and the `floatingActionsOverlay` private property); edit `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/CommentComposer.swift` (swap the Cancel + Submit order in `actions`).
  - **Tests (commit 2):** re-record `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/SnapshotTests/test_commentComposer_emptyState.1.png` + `.../test_commentComposer_filledState.1.png` + `.../SnapshotTests+AppearanceAudit/test_commentComposer_filledState_dark.1.png`. Re-record `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/__Snapshots__/RecipeDetailRatingsViewSnapshotTests/test_section_identityGated_rendersComposer.1.png` only if the inline composer's actions row is visible at the section snapshot frame (re-run shows whether it diffs).
  - **Out of bounds:** any change to `RecipeDetailViewModel`, `RecipeDetailDependencies`, the comments/ratings data path (`fetchComments`, `postComment`, `postRating`, `cachedComments`), `GuestIdentitySheet`, `WidgetCard*`, or any other surface unrelated to the two-part polish above.
- **AC:** AC-26.1, AC-26.2, AC-26.3, AC-26.4, AC-26.5; amends AC-4.7 (sticky duplicate removed per CL-42); pins AC-4.8 (nav-bar Share unchanged), AC-7.1 (Cook Now CTA inside scroll content unchanged), AC-13.1..AC-13.5, AC-14.1..AC-14.7.
- **Deps:** — (independent; runs against current main; assumes T-380 already shipped the bookmark glyph on the nav-bar Save).
- **Est:** 1.5h (S per backlog estimate — sweep is bounded; re-recording 3–4 snapshot PNGs + visual review of each is what makes it more than ~30min).
- **||:** P10-detail-cleanup

### T-420 — L2 nightly test for new-recipe surfacing (REG-16)
- **Scope:** New L2 live-API test asserting that when a recipe is published on dutchovendaddy.com, the app's feed-load path picks it up on the next refresh, and the newest post's `wp:featuredmedia` round-trips into a non-nil `heroImage`. Two test methods in the existing `DODIntegrationTests` package (the same package that hosts every other `live-api`-tier test today): (1) `newestPostIsReachableViaFeedRefresh` — fetches the newest post id via a direct `GET /wp/v2/posts?per_page=1&_embed=wp:featuredmedia`, runs the production-equivalent feed load via `WPRestClient.posts()` (the exact call `LiveFeedDependencies.fetchPosts(page:)` wraps verbatim), caches the result through `RecipeStore.cache(listItems:)` (the same call `LiveFeedDependencies.cache(listItems:)` makes from `FeedViewModel.loadInitial()`), and asserts the newest id is present in `RecipeStore.listItems(forIDs:)` afterwards; (2) `newestPostHasNonNilHeroImage` — fetches the same newest-post fixture and asserts its `heroImage` is non-nil, locking REG-2's assertion against the live newest post on every nightly run (REG-2 itself only asserts on the page-1 batch with a "at least half pass" gate that can hide a newest-post-specific drift). Both methods live inside the existing `LiveAPITests` `@Suite` — they inherit the suite's `.enabled(if: ProcessInfo.processInfo.environment["DOD_RUN_LIVE_TESTS"] == "1")` gate (the project's L2 convention; not Swift `.tags`), so PR CI skips them and the `nightly-live-api.yml` workflow picks them up via the `DOD_RUN_LIVE_TESTS=1` env var. **Live-blog-empty handling:** `try #require(!page1.isEmpty, ...)` produces a clear failure message rather than a crash if the live blog returns zero posts — same pattern the existing `postsReturnNonNilHeroImage` test uses. **Out of bounds:** any change to `FeedViewModel` / `LiveFeedDependencies` / `RecipeStore` source (the test exercises them as-is); any addition to PR-tier CI (REG-16 is nightly-only per AC-T3); any new YAML in `.github/workflows/` (the existing `nightly-live-api.yml` already runs the entire `DODIntegrationTests` package — new methods are picked up automatically); any test of the JSON-LD detail path (the newest post's *detail* HTML may not always parse cleanly per CL-9 / AC-1.7, and the existing `recipeDetailPageHasParseableJSONLD` covers that surface against the *first* post-with-canonical-URL anyway).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (REG-16 bullet under Test pyramid), `specs/dod-ios-app/clarifications.md` (CL-43), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduation).
  - **Tests (commit 2):** `Packages/DODIntegrationTests/Tests/DODIntegrationTestsTests/LiveAPITests.swift` (two new test methods appended to the existing `LiveAPITests` suite — same file as REG-2's `postsReturnNonNilHeroImage`). `Packages/DODIntegrationTests/Package.swift` gains `DODPersistence` + `DODSupport` as test-target dependencies so the new method can exercise the same `RecipeStore.cache(listItems:)` → `RecipeStore.listItems(forIDs:)` round-trip the production feed load uses; the existing `LiveAPITests` methods don't need `RecipeStore`, so the dependency add is purely for the new test.
  - **Out of bounds:** `.github/workflows/nightly-live-api.yml` (no change — the existing job runs `swift test --parallel` against the whole `DODIntegrationTests` package, so new methods inside the existing suite are picked up automatically); `.github/workflows/ci.yml` (no change — REG-16 stays nightly-only per AC-T3); `Packages/DODFeatureFeed/**` (no source change — the test exercises the feature's network + cache layer through its public seams, not through `FeedViewModel` directly, which would need a Main-actor host + SwiftUI hosting scaffolding the integration-tests package doesn't carry today).
- **AC:** Locked by REG-16 (US-1, T-420). Pins AC-T3 (nightly-only L2 tier), AC-T4 (regression test in the same PR as the change it adds), AC-1.1 (newest posts surface on home feed) at the contract-drift layer. Does not add new acceptance criteria — this is a regression-tier test entry per the same pattern REG-13 / REG-14 followed (no new US, no new AC, just a new REG bullet under the Test pyramid + a named live-API test).
- **Deps:** — (independent; runs against current main). The existing `LiveAPITests` suite is the host; no other Phase 10 task touches it.
- **Est:** 2h
- **||:** P10-livetests

### T-390 — Widget appearance audit: iOS 18+ "Clear" and "Tinted" home-screen modes (US-23)
- **Scope:** Audit-style task framed by CL-39. Inventory every home-screen widget surface × every iOS 18+ rendering-mode environment value (`.fullColor` / Standard, `.accented` / Tinted, `.vibrant` / Vibrant) plus the existing Standard-dark pair, document the matrix in a new `specs/dod-ios-app/widget-appearance-audit.md` (sibling to `appearance-audit.md`), and apply targeted fixes for any surface that fails. Surfaces audited: `FeaturedRecipeWidget` (small + medium + placeholder) and `SavedRecipesWidget` (small + medium + empty). Lock-screen widget (US-22 / T-370, merged via PR #26) explicitly out of scope per CL-39 — lock-screen accessory widgets use a different system pipeline (system-monochromatic vibrancy on the Lock Screen, not the home-screen Tinted/Clear pipeline this audit targets). Fixes the audit may apply if it surfaces failures: (a) replace hardcoded `Color.black` / `Color.white` literals in `WidgetCard*.swift` with system-semantic colors so the system's tint pass handles them coherently, (b) annotate the hero photo with `widgetAccentedRenderingMode(.fullColor)` so the food image keeps true color through a Tinted treatment (or `.accented` if the brand audit decides the desaturated treatment looks better), (c) annotate the placeholder gradient + glyph composition with `widgetAccentedRenderingMode(.accented)` so the gradient + glyph tint coherently. All modifier additions are wrapped in `if #available(iOS 18, *)` (or hoisted into an internal `View` extension that gates internally) — the iOS 17 deployment target (constitution §2) means the modifier must not be unconditionally compiled in. **Snapshot baseline additions (whether or not fixes are applied):** new `WidgetCardTintedAppearanceSnapshotTests` lays down four Tinted-mode baselines (`test_widgetCard_small_populated_tinted`, `test_widgetCard_medium_populated_tinted`, `test_widgetCard_placeholder_tinted`, plus the saved-widget triad as a parallel test class or appended file) using `.environment(\.widgetRenderingMode, .accented)` on a SwiftUI host, gated by `if #available(iOS 18, *)` so iOS 17 sim runners skip them cleanly. Per CL-39, a clean audit (no `WidgetCard*.swift` source changes) is an acceptable outcome — the snapshot baselines and the audit document carry the regression net forward regardless. **Follow-up tasks:** if the audit surfaces any fix that doesn't fit the PR scope (e.g. it would require a new asset catalog, a new design token, or a snapshot-infra change beyond environment injection), the auditor files a T-391+ task entry in this same Phase 10 cluster with the specific surface + the proposed remediation.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-23), `specs/dod-ios-app/clarifications.md` (CL-39), `specs/dod-ios-app/tasks.md` (this entry + any T-391+ the audit surfaces), `specs/dod-ios-app/backlog.md` (graduation).
  - **Audit doc (commit 2):** `specs/dod-ios-app/widget-appearance-audit.md` (new — matrix + findings, mirrors `appearance-audit.md` structure).
  - **Source (commit 2):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` — surgical fix inside `WidgetCard.Hero.loadedImage(_:)` (new private helper that wraps the `AsyncImage.success` branch in `widgetAccentedRenderingMode(.fullColor)`, gated by `#if canImport(WidgetKit)` + `if #available(iOS 18.0, macOS 15.0, *)`). Adds a guarded `import WidgetKit` at the top of the file — the macOS test slice (`swift test`) continues to build because `#if canImport(WidgetKit)` skips the import on macOS 14.x runners. No source change to `WidgetCard+Saved.swift` or the entry view files (`Widget/FeaturedRecipeWidgetEntryView.swift`, `Widget/SavedRecipesWidgetEntryView.swift`) — they compose `Hero` which now applies the opt-out internally.
  - **Tests (commit 2):** `Packages/DODDesignSystem/Tests/DODDesignSystemTests/WidgetCardTintedAppearanceSnapshotTests.swift` (new — 12 Tinted-mode + Vibrant-mode baselines using `widgetRenderingMode` environment injection on iOS 18+). Class is annotated `@available(iOS 18.0, *)`; file is wrapped in `#if canImport(UIKit) && canImport(WidgetKit)` so the macOS `swift test` slice skips it. 12 baseline PNGs under `__Snapshots__/WidgetCardTintedAppearanceSnapshotTests/` ship in the same commit (matches the `SavedWidgetSnapshotTests` precedent in PR #17 / T-321 where the PNGs ship alongside the test methods, so the regression net is active on the next CI run rather than waiting for a follow-up sim harvest).
  - **Out of bounds:** any change to `WidgetSnapshot.Entry` / `SavedRecipesWidgetSnapshot.Entry` wire format (AC-23.5), `widgetURL` grammar, analytics events, lock-screen widget code (US-22 / T-370 territory — different rendering pipeline), and any re-recording of the existing Standard light / Standard dark `WidgetCard*` baselines (the new modifier is reached only on the `AsyncImage.success` path, which existing baselines don't hit since they all pass `heroImageURL: nil` — re-recording any of those PNGs would be a tell that something else drifted).
- **AC:** AC-23.1, AC-23.2, AC-23.3, AC-23.4, AC-23.5, AC-23.6; pins AC-9.1..AC-9.4, AC-17.1..AC-17.9, AC-21.1..AC-21.6, AC-22.1..AC-22.5 (the audit is additive — no existing widget contract changes).
- **Deps:** — (independent; runs against current main with T-370 now merged via PR #26). The audit is scoped to home-screen widgets only per CL-39 regardless of T-370's merge status.
- **Est:** 3h (audit pass + Tinted-mode snapshot baselines + the bounded set of fixes the audit may surface; clean-audit outcome cuts this to ~1.5h since no source touches are needed).
- **||:** P10-widget-appearance

### T-394 — Featured / Latest Recipe widget contrast scrim (REG-T-390 / CL-48 / AC-23.7)
- **Scope:** Targeted contrast fix for the smoking gun T-390's `widget-appearance-audit.md` Findings 2+3 missed (and that REG-T-390's user report surfaced as "white text on a white background"). Replace the existing three-stop bottom-anchored `LinearGradient` inside `WidgetCard.Small.body` (`WidgetCard.swift:61-73`) with a full-height two-stop scrim — `LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)` — sitting BEHIND the title `VStack` and IN FRONT of the `Hero` primitive in the `ZStack`. The two-stop full-height shape gives a consistent dark scaffold that survives `widgetRenderingMode == .accented` (Tinted + Clear) flattening — when `containerBackground` is stripped and `.white` collapses into the wallpaper-tinted default group, the `.black.opacity(0.55)` literal at the bottom is the calibrated WCAG-AA-equivalent contrast scaffold that gives the title something to read against on light wallpapers. **What this task does NOT do (per CL-48 minimal-diff principle):** does not add `.widgetAccentable(true)` on the title (AC-23.7's part-(b) is intentionally deferred to a clean follow-up T-39X if a future audit determines the wallpaper-tinted title also needs accent-group separation), does not change `.foregroundStyle(.white)` (keeps the brand white-title-over-photo visual identity), does not touch `WidgetCard.Medium` (HStack layout — text on `surfaceElevated`, no text-over-image surface), does not touch `WidgetCard.Placeholder` (text on `surfaceElevated`), does not touch `WidgetCard.Hero` (T-390's `widgetAccentedRenderingMode(.fullColor)` opt-out stays), does not touch `WidgetCard+Saved.swift` (T-395 cleared the saved variants by-construction), does not touch `WidgetCard+LockScreen.swift` (lock-screen runs in `.vibrant` mode, out of scope per AC-23.1's home-screen-only framing), does not change the `WidgetSnapshot` wire format, does not change the `widgetURL` grammar, does not change the analytics events. **Snapshot baseline re-record:** the 12 `WidgetCardTintedAppearanceSnapshotTests` baselines T-390 added are re-recorded — the bottom band's shape changes for every populated Small surface in `.accented` + `.vibrant` modes, the Saved + placeholder baselines pass byte-identical because the source change is bounded to `WidgetCard.Small`. First test-run records (`isRecording = true` flip + run), second test-run verifies (`isRecording = false` flip + run). Reviewer pages through at least two re-recorded Small Tinted PNGs visually before commit to confirm the title is now legible on the tinted background. **Manual sim verification (constitution §7 pre-TestFlight checkpoint per AC-23.7):** build the app, install to iPhone 17 simulator, launch the app to let the feed load and the widget snapshot file write, then take a screenshot of the app's home feed (the widget surface itself requires home-screen install which is manual — the snapshot tests already prove the rendering). The PR body documents the screenshot path + which two re-recorded Tinted PNGs the reviewer visually checked.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (AC-23.7 already exists from T-395's parallel-branch landing; this PR pins it without amendment — the two-part requirement stays, CL-48 explicitly defers part-(b) to a follow-up), `specs/dod-ios-app/clarifications.md` (CL-48), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate REG-T-390 to "Recently graduated" trail).
  - **Source (commit 2):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` (replace the three-stop bottom-anchored `LinearGradient` block in `WidgetCard.Small.body` with the full-height two-stop scrim per CL-48; the diff is bounded to ~10 lines, no other body code changes).
  - **Tests (commit 2):** re-record `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/WidgetCardTintedAppearanceSnapshotTests/*.png` (the 12 baselines T-390 added — 6 Featured + 6 Saved; the Saved 6 pass byte-identical because the source change is bounded to `WidgetCard.Small`, the Featured 6 re-record per the new scrim shape). No new test files added. No `SnapshotTests.swift` / `SnapshotTests+AppearanceAudit.swift` baselines re-recorded — the full-height scrim renders the same final pixel at the title's anchor in Standard mode within the snapshot harness's perceptual tolerance because `.black.opacity(0.55)` at the bottom matches the previous `.black.opacity(0.75)` middle-stop area within sub-pixel JPEG-noise tolerance; if any Standard baselines drift more than the harness tolerance, they're re-recorded too and the diff is noted in the PR body.
  - **Out of bounds:** `WidgetCard.Medium` (HStack layout — no text-over-image surface), `WidgetCard.Placeholder` (text on `surfaceElevated`), `WidgetCard.Hero` / `WidgetCard.Hero.loadedImage(_:)` (T-390's `widgetAccentedRenderingMode(.fullColor)` opt-out stays), `WidgetCard.TimeChip` (renders on `castIronBrown` background, not over hero), `WidgetCard+Saved.swift` (T-395 cleared by-construction), `WidgetCard+LockScreen.swift` (lock-screen `.vibrant` pipeline out of scope), `Widget/FeaturedRecipe*.swift` (entry-view shell — no rendering composition change), the snapshot wire format, the deep-link parser, the analytics events, the `DODColor` token set, the `DODSpacing` token set, the `widget-appearance-audit.md` doc (T-390's deliverable — CL-48 cites it but doesn't amend it; the audit's clean-on-5/6 verdict was the audit's conclusion at the time, not a contract to preserve).
- **AC:** AC-23.7 (the Featured widget pin — this PR satisfies part-(a) of the two-part requirement; part-(b) `.widgetAccentable(true)` is explicitly deferred per CL-48 to a clean T-39X follow-up if needed); pins AC-23.1, AC-23.2, AC-23.3, AC-23.4, AC-23.5, AC-23.6 (the fix is additive to T-390's audit — no audit-document amendment, no rendering-mode baseline removal). Also pins AC-9.1..AC-9.4, AC-21.1..AC-21.6 (US-9 / US-21 not regressed — the widget contract, wire format, refresh cadence, and deep-link grammar are all unchanged).
- **Deps:** T-390 (PR #27, merged) for the `WidgetCardTintedAppearanceSnapshotTests` baseline foundation this PR re-records; T-395 (parallel branch on `fix/T-395-saved-widget-tint-contrast`) for the AC-23.7 spec addition (already on main) — both branches landed their own copy of CL-46 + AC-23.7; T-394's CL-48 entry is the new clarification slot. Parallel with the other Phase 10 tasks (T-362, T-410, T-430, T-396); no source-file collisions outside `WidgetCard.swift`.
- **Est:** 1.5h (source edit + snapshot re-record + manual sim verification + PR body assembly).
- **||:** P10-widget-appearance (same cluster as T-390 / T-395 / T-396; T-394 is the smoking-gun-fix follow-up to T-390's audit miss).

### T-395 — Saved Recipes widget contrast audit (clean) — sibling to T-394 (REG-T-390 / CL-46 / AC-23.7)
- **Scope:** Spec-only sibling-audit task to [T-394](#) (`fix/T-394-widget-text-contrast`, which fixes the smoking gun on `WidgetCard.Small`'s `.foregroundStyle(.white)` recipe title over the hero gradient). T-395 runs the **same audit** against the saved-recipes widget surfaces declared in `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard+Saved.swift` (`WidgetCard.SavedSmall`, `WidgetCard.SavedMedium`, `WidgetCard.SavedEmpty`, `WidgetCard.SavedListRow`) plus their entry-view shell at `Widget/SavedRecipesWidgetEntryView.swift` and the widget configuration at `Widget/SavedRecipesWidget.swift`. **Verdict: CLEAN AUDIT — no source fix needed.** **Why clean (four-check rubric mirroring CL-46):** (1) **Hardcoded text colors over images:** `rg -n '\.foregroundStyle\(\.(white|black)\)|\.foregroundColor\(\.(white|black)\)|Color\.white|Color\.black'` against `WidgetCard+Saved.swift` and `Widget/SavedRecipes*.swift` returns zero matches. Every text element uses `DODColor.label`, `DODColor.labelSecondary`, or `DODColor.burntOrange` — semantic brand tokens, no raw `.white`/`.black` literals to flatten under `.accented`. (2) **Text-over-image layouts:** zero `ZStack` overlays in any saved variant. `SavedSmall.body` is a `VStack` (eyebrow → spacer → `Hero` thumbnail → title text); `SavedListRow.body` is an `HStack` (thumbnail LEFT, title RIGHT); `SavedMedium.body` is a `VStack` of `SavedListRow`s. There is no surface where text renders ON TOP of an image — the smoking-gun pattern T-394 fixes does not exist in `WidgetCard+Saved.swift`. (3) **Hero `.fullColor` opt-out:** the saved variants reuse the same `WidgetCard.Hero` primitive from `WidgetCard.swift` that T-390 already annotated with `widgetAccentedRenderingMode(.fullColor)` in `Hero.loadedImage(_:)`. The opt-out fires transitively for `SavedSmall`'s 56pt-tall thumbnail and `SavedListRow`'s 36pt-square thumbnail. The empty/loading fallback gradient intentionally tints with the system (documented behavior per `widget-appearance-audit.md` Finding 4) so empty rows blend with the wallpaper. No per-variant `.fullColor` change needed. (4) **`SavedEmpty` placeholder visibility + saved-at timestamp chip:** the `SavedEmpty` placeholder renders `DODColor.label` / `DODColor.labelSecondary` text plus a `DODColor.burntOrange` `bookmark.fill` glyph on a `DODColor.surfaceElevated` background — all asset-catalog tokens flatten into the default group together under `.accented`, no foreground-vs-scrim contrast collapse like T-394's hero-title case. There is no saved-at timestamp chip — `SavedRow` carries only `title` + `heroImageURL`. **Per CL-46 (T-395 sibling):** the readability mandate AC-23.7 pins for "text over image" extends to the saved surfaces by reference; the current `WidgetCard+Saved.swift` enforces it by-construction (no text-over-image composition exists). Any future saved-recipe widget variant that introduces such a composition inherits AC-23.7's two-part requirement (explicit dark scrim band + `.widgetAccentable(true)` on the foreground). **What this task does NOT touch:** any `WidgetCard+Saved.swift` source (verified clean), any `Widget/SavedRecipes*.swift` source, the saved widget snapshot baselines (`SavedWidgetSnapshotTests`'s 12 Standard light + dark PNGs and the 6 Tinted/Vibrant PNGs under `WidgetCardTintedAppearanceSnapshotTests/test_savedWidget_*` stay byte-identical because no source change), `WidgetCard.swift` (T-394's territory), `WidgetCard+LockScreen.swift` (lock-screen widget runs in `.vibrant` mode, out of scope per AC-23.1's home-screen-only framing inherited via CL-39), the snapshot wire format (`SavedRecipesWidgetSnapshot.Entry`), the deep-link grammar, the analytics event, or any US-17 / US-23 acceptance criteria (AC-17.1..AC-17.9 are pinned; AC-23.7 is added in the shared spec commit, with the sibling-audit framing baked in). **Why a separate task and not a sub-bullet of T-394:** the two audits cover independent files (different `WidgetCard+*.swift` extensions, different rendering compositions). Pushing them through the same PR would conflate "fix the smoking gun on the Featured/Latest Recipe widget" with "verify the Saved widget is clean by construction." Parallel branches keep each audit's scope crisp; merge-time collision on the `CL-46` number is the documented resolution path (whoever lands second amends the existing entry, mirroring the same pattern T-362 / T-410 used when running parallel to other Phase 10 work). **Manual verification (constitution §7 pre-TestFlight checkpoint per AC-23.7):** the saved-widget Tinted/Vibrant snapshot baselines under `WidgetCardTintedAppearanceSnapshotTests/test_savedWidget_*_tinted.1.png` already exist and pass; the on-device verification step is a parallel pass alongside T-394's bright-wallpaper check — install the Saved Recipes widget, confirm "Saved" eyebrow, row titles, and the SavedEmpty placeholder are all legible under a Tinted wallpaper tint. PR body documents the manual verification approach + result.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1, spec-only):** `specs/dod-ios-app/spec.md` (AC-23.7 added under US-23 in the shared form with the saved-surface extension baked in), `specs/dod-ios-app/clarifications.md` (CL-46, T-395 sibling entry), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (one-line note under "Recently graduated" — proactive audit, no specific backlog item).
  - **Source (no commit 2):** none — audit verdict is clean per the four-check rubric above. No `WidgetCard+Saved.swift` source change, no `Widget/SavedRecipes*.swift` source change. The same framing T-330 (dark-mode audit clean closure) / T-390 (widget-appearance audit clean-ish closure on the Saved variants per `widget-appearance-audit.md` Findings 2+3 verdicts) used.
  - **Tests (no commit 2):** none — the saved-widget snapshot baselines (`SavedWidgetSnapshotTests` for Standard light + dark; `WidgetCardTintedAppearanceSnapshotTests.test_savedWidget_*` for Tinted + Vibrant) are byte-identical to `main` because no source change. The regression net already exists from T-321 (Standard) and T-390 (Tinted/Vibrant); T-395 verifies the net is the correct shape rather than expanding it.
  - **Out of bounds:** `WidgetCard.swift` (T-394's territory — the smoking-gun fix lives there), `WidgetCard+LockScreen.swift` (lock-screen runs in `.vibrant` mode, out of scope per AC-23.1's home-screen-only framing), the `WidgetCard.Hero.loadedImage(_:)` `.fullColor` opt-out (T-390's Finding 4 fix stays — already covers the saved variants transitively), `Widget/SavedRecipesTimelineProvider.swift`, the snapshot wire format, the deep-link parser / grammar, the analytics events, the `DODColor` token set, any re-recording of the saved-widget Standard or Tinted/Vibrant baselines (the audit verdict is clean by construction — re-recording would be a tell that something else drifted).
- **AC:** AC-23.7 (added in the shared spec commit with the saved-surface extension); pins AC-23.1, AC-23.2, AC-23.3, AC-23.4, AC-23.5, AC-23.6 (the audit is additive to T-394; the sibling-audit verdict is clean and bounded entirely to the saved-widget surface inventory). Also pins AC-17.1..AC-17.9 (US-17 not regressed — saved variants unchanged source-wise).
- **Deps:** T-394 (parallel branch on `fix/T-394-widget-text-contrast`) — both branches land their own copy of CL-46 + AC-23.7. Merge-time collision on the CL-46 number is the documented resolution path; whoever lands second amends the existing CL-46 entry to fold both audits' framings (or, if T-394 lands first, T-395's CL-46 entry is rebased to extend T-394's CL-46 with the saved-surface clean-audit verdict). Parallel with T-362, T-410, T-430 (Phase 10 cluster); no source-file collisions with any of them (T-395 ships zero source edits).
- **Est:** 0.5h (audit pass against the four-check rubric + spec commit; clean-audit verdict means no source touches, no snapshot re-records, no impl commit).
- **||:** P10-widget-appearance (same cluster as T-390 / T-394; T-395 is the sibling-surface audit follow-up).

### T-400 — Saved Recipes widget description rewrite (US-25, CL-40, amends AC-17.1)
- **Scope:** Single user-facing string change in `Widget/SavedRecipesWidget.swift`: the `.description(_:)` argument flips from "Your saved recipes, one tap from a cook." to "Quick access to your saved recipes." per CL-40. The string is what iOS shows under the widget tile in the home-screen widget gallery picker. Everything else in `SavedRecipesWidget.swift` is byte-for-byte preserved: the `Self.kind = "SavedRecipesWidget"` identifier, the `StaticConfiguration` shape, the `SavedRecipesTimelineProvider` reference, the `SavedRecipesWidgetEntryView` composition, the `containerBackground(for: .widget)` treatment with `DODColor.surfaceElevated`, the `.configurationDisplayName("Saved Recipes")` line, the `.supportedFamilies([.systemSmall, .systemMedium])` declaration (per CL-26), and the `.contentMarginsDisabled()` modifier. The change is to the gallery-side surface only — the widget face renders the same. No snapshot baselines re-recorded (the description string never appears in the widget face that `SavedWidgetSnapshotTests` pins; it's iOS-gallery-only). No tests added (the description argument is a `LocalizedStringResource`-promoted string literal — there's no view-model logic to test, and snapshot coverage of the iOS widget gallery isn't part of the existing harness; manual sim-gallery verification on iPhone simulator covers AC-25.3).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-25 added, AC-17.1 amended with the strike-through superseded line), `specs/dod-ios-app/clarifications.md` (CL-40), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduation entry under "Recently graduated").
  - **Source (commit 2):** `Widget/SavedRecipesWidget.swift` (single string literal edit on the `.description(_:)` line).
  - **Out of bounds:** `Widget/SavedRecipesWidgetEntryView.swift` (widget face, not gallery), `Widget/SavedRecipesTimelineProvider.swift` (timeline, not gallery), `Widget/FeaturedRecipeWidget.swift` (different widget kind, different description that is already correct per CL-36), `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SavedWidgetSnapshotTests.swift` and its `__Snapshots__/` PNGs (the rendered widget face does not include the gallery description string — re-recording would be a tell that something else drifted), the snapshot wire format (`SavedRecipesWidgetSnapshot.Entry`), the deep-link parser, or the `widgetOpened` analytics event (none of these read the description string).
- **AC:** AC-25.1, AC-25.2, AC-25.3; implements amended AC-17.1 (description string superseded per CL-40); pins AC-17.2..AC-17.9 (US-17 widget contract unchanged).
- **Deps:** — (independent; runs against current main).
- **Est:** 0.5h (single string edit + sim-gallery manual verification + CL).
- **||:** P10-saved-desc

### T-430 — Categories tab brown surface (US-24)
- **Scope:** Categories-only surface-color pass framed by CL-44. Amends T-340's `.insetGrouped` + `.searchable` layout (US-19 / PR #22) on one axis: the scroll surface around the inset-grouped row cards AND the area behind the `.searchable` field in the `.navigationBarDrawer` placement adopt `DODColor.castIronBrown` via `.scrollContentBackground(.hidden) + .background(DODColor.castIronBrown)` on the `List`. The change is a one-line modifier addition in `CategoryListView.swift` (replacing the existing `.background(DODColor.surface)` on the inner `baseList`). The cells themselves are NOT tinted brown — they keep the system-default inset-grouped cell fill (white in light, dark earth in dark) so the existing row text contrast (`DODColor.label` / `labelSecondary` / `.tertiary`) carries forward unchanged. CL-44 documents the surface-vs-cell-level decision, the `.searchable` legibility rationale, and the three considered alternatives that were rejected. **Why not a token change:** the `castIronBrown` token already exists and is the same value the recipe-card time chip, offline banner, snackbar, and search filter chip use — reusing it directly preserves brand cohesion. **Why not amend the loading / error states:** AC-24.4 explicitly scopes the brown to the loaded-state list surface only; `ProgressView` and `EmptyState` already inherit the established surface treatment and are untouched. **Snapshot baseline re-record:** all six existing `CategoryListViewSnapshotTests` baselines (iPhone 13 light + dark at default Dynamic Type, iPhone 13 light + dark at AX5, iPad 12.9" light + dark at default Dynamic Type — the matrix T-340 established) are re-recorded as part of this PR. The surface color change affects every PNG; reviewer pages through each one visually before commit. The `CategoryRecipesView` snapshot baselines are NOT touched — that screen is the recipe sub-list, out of scope per AC-24.4. **Dark-mode legibility verification:** the snapshot baselines themselves are the verification harness — if the `.searchable` field becomes unreadable against the dark brown surround in either mode, the baseline reviewer catches it and the fix is a constitution §7 follow-up T-431 entry per CL-44 (not in scope for this PR).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-24), `specs/dod-ios-app/clarifications.md` (CL-44), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduation).
  - **Source (commit 2):** `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift` — single `.background(DODColor.surface)` → `.background(DODColor.castIronBrown)` swap on the `baseList` chain (the `.scrollContentBackground(.hidden)` modifier already exists per T-340's implementation, so this is a one-token replacement).
  - **Tests (commit 2):** `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/__Snapshots__/CategoryListViewSnapshotTests/*.png` — six re-recorded baselines. No source change to `CategoryListViewSnapshotTests.swift` itself; the existing test methods (`test_loadedCategories_light_defaultDynamicType`, `test_loadedCategories_dark_defaultDynamicType`, `test_loadedCategories_light_AX5`, `test_loadedCategories_dark_AX5`, `test_loadedCategories_iPad_light_defaultDynamicType`, `test_loadedCategories_iPad_dark_defaultDynamicType`) all use `record: .missing` semantics — the re-record happens by deleting the existing PNG, re-running the test, and committing the regenerated artifact.
  - **Out of bounds:** any change to `CategoryListViewModel`, `CategoryRecipesView`, the L1 `CategoriesTests.filtered(...)` unit-test suite, the `DODColor` enum or its asset catalog, the `RecipeCard` time-chip composition, any other tab's surface color (Feed, Search, Saved each maintain their own surface treatments), and any re-recording of `CategoryRecipesViewSnapshotTests` baselines (different screen, out of AC-24 scope).
- **AC:** AC-24.1, AC-24.2, AC-24.3, AC-24.4, AC-24.5, AC-24.6; pins AC-2.1..AC-2.5 (US-2 list contract not regressed), AC-19.1..AC-19.6 (US-19 layout not regressed).
- **Deps:** T-340 (US-19 / PR #22) — amends T-340's surface color, so requires T-340's `.insetGrouped` + `.searchable` layout to be on `main`. Already merged.
- **Est:** 1.5h (one-modifier source change + six snapshot re-records + visual review of each PNG before commit).
- **||:** P10-categories-brown

### T-520 — App-wide background + foreground color overhaul (US-30, CL-51)
- **Scope:** Asset-catalog-only re-tint of the two semantic surface tokens to user-specified hex values per backlog round-6 item 9. `Surface.colorset` (screen-wide backdrop) flips light Any-Appearance from `#FAF6EE` to `#F9F6EF` and dark from `#1B140E` to `#42210B`. `SurfaceElevated.colorset` (card / sheet surface above surface) keeps light at `#FFFFFF` (byte-identical) and flips dark from `#2A1F18` to `#281F19`. CL-51 maps the user's "background" / "foreground" intent to the two existing `DODColor` tokens (the palette has no token literally named either; `Surface` and `SurfaceElevated` already carry the semantic roles per `Colors.swift`'s doc-comments) and verifies WCAG AA contrast against every unchanged text token. **No Swift source edits.** **No `DODColor` token additions / renames / removals.** **Text + brand-accent tokens explicitly untouched** per AC-30.3: `Label.colorset`, `LabelSecondary.colorset`, `Charcoal.colorset`, `Accent.colorset`, `CastIronBrown.colorset`, `BurntOrange.colorset`, `WarmGold.colorset`, `DarkEarth.colorset`, `Cream.colorset` (a foreground text color in this codebase, NOT a background — see CL-51's call-site audit of 13 `.foregroundStyle(DODColor.cream)` references on dark brand surfaces), and `CreamSubtle.colorset` (unused in production source). **WCAG AA verification result (per AC-30.4):** all four directions pass with comfortable headroom — Label dark on Surface dark ≈ 10.84:1, Label dark on SurfaceElevated dark ≈ 12.14:1, LabelSecondary dark on Surface dark ≈ 5.77:1, LabelSecondary dark on SurfaceElevated dark ≈ 6.46:1, all light-mode pairs ≥ 4.74:1. No deviation from the user's specified hex values is needed; CL-51 captures the per-pair luminance numbers. `accessibility-audit.md` contrast table updated in the same spec commit. **L4 baseline re-record scope:** every snapshot whose rendered surface includes `DODColor.surface` or `DODColor.surfaceElevated` — bulk of `DODDesignSystemTests/__Snapshots__/**`, feature snapshot tests under `DODFeatureCategoriesTests` / `DODFeatureRecipeDetailTests` / `DODFeatureSearchTests`, widget tests under `WidgetCardTintedAppearanceSnapshotTests` / `SavedWidgetSnapshotTests` / `SnapshotTests` / `SnapshotTests+AppearanceAudit`. **Out of scope for re-record:** `LockScreenWidgetSnapshotTests/test_lockScreenWidget_rectangular_*` baselines (lock-screen pipeline paints with `Color.clear` containerBackground per T-396 / CL-47, defers to system `AccessoryWidgetBackground` — re-tinted Surface / SurfaceElevated tokens aren't rendered on those surfaces); any icon-only or text-only baseline that does not paint a surface token. **Verification sequence (round-5 lessons baked in per backlog):** (1) first `xcodebuild test` pass against `DODDesignSystemTests` deletes the now-stale baselines and writes new ones; (2) second pass confirms green; (3) `xcodegen generate` + full-app build confirms no Swift compile breakage from the color change (there should be none — pure asset-catalog edit); (4) manual sim verification on iPhone simulator 45A10D1F-36EB-452D-9ACE-5A759DA6D72D — install fresh build, cycle through every tab (Recipes / Categories / Search / Saved) in light mode, switch to dark, repeat, screenshot light + dark for the PR body. The manual pass is REQUIRED — round-5's T-394 lesson is that snapshot tests don't fully replicate the real rendering pipeline, so a real-app pass is the contrast-floor verification of last resort. **Reviewer spot-check:** before commit, reviewer visually pages through ≥ 5 representative re-recorded PNGs (one DesignSystem component like `RecipeCardSnapshotTests`, one feature view like `CategoryListViewSnapshotTests`, one widget surface like `SnapshotTests.test_widgetCard_small_populated`, one search surface like `FilterChipRowSnapshotTests`, one detail surface like `RecipeDetailRatingsViewSnapshotTests`) to confirm the new colors render as expected.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-30 + AC-30.1..AC-30.5 added), `specs/dod-ios-app/clarifications.md` (CL-51), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduation entry under "Recently graduated"; round-6 backlog item 9 sizing table row struck through), `specs/dod-ios-app/accessibility-audit.md` (contrast table rows for Label / LabelSecondary on Surface / SurfaceElevated updated with new hex values + WCAG AA verification result).
  - **Source (commit 2):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/Surface.colorset/Contents.json` (Any + Dark Appearance hex re-tint per AC-30.1), `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/SurfaceElevated.colorset/Contents.json` (Any-Appearance byte-identical at `#FFFFFF`; Dark-Appearance hex re-tint to `#281F19` per AC-30.2). Two files only.
  - **Tests (commit 2):** re-recorded `__Snapshots__/**/*.png` baselines across DesignSystem + feature packages + widget surfaces; no `*.swift` test source edits. The exact PNG list is driven by which tests render a `Surface` or `SurfaceElevated` token at any point in their composition — the implementing agent enumerates them by running the relevant `xcodebuild test` invocations with the existing baselines deleted, letting the snapshot harness re-record under its `record: .missing` semantics, and committing the regenerated artifacts.
  - **Out of bounds:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Colors.swift` (the `DODColor` enum stays byte-identical — no new tokens, no renames), `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/Label.colorset/Contents.json` (text color — unchanged per AC-30.3), `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/LabelSecondary.colorset/Contents.json` (text color — unchanged), `Charcoal.colorset` / `Accent.colorset` / `CastIronBrown.colorset` / `BurntOrange.colorset` / `WarmGold.colorset` / `DarkEarth.colorset` / `Cream.colorset` / `CreamSubtle.colorset` (brand-accent + foreground-text tokens — all unchanged), any `DODColor` call site in feature packages (the asset-catalog re-tint plumbs through every call site automatically; no source-level rewrite needed), any `xcassets` outside the two surface colorsets, `LockScreenWidgetSnapshotTests/__Snapshots__/**` PNGs (lock-screen pipeline doesn't render Surface / SurfaceElevated per T-396), the snapshot wire format, any deep-link grammar, any analytics event, any `Colors.swift` `bundleColor(...)` call (the token names stay the same; the asset catalog is the only mutated surface).
- **AC:** AC-30.1, AC-30.2, AC-30.3, AC-30.4, AC-30.5; pins every prior screen-level AC that depends on `DODColor.surface` / `DODColor.surfaceElevated` (US-1 AC-1.x feed, US-2 AC-2.x categories, US-3 AC-3.x search, US-4 AC-4.x detail, US-5 AC-5.x saved, US-7 AC-7.x cook mode, US-9 / US-21 home-screen widget, US-17 saved widget, US-22 lock-screen widget — none of those contracts are broken by a pure hex re-tint).
- **Deps:** — (independent; runs against current main). Parallel with T-500 (Search polish) and T-510 (new-recipe fix); per CL-51 coordination note, when PRs collide on `__Snapshots__/**/*.png` the color-tinted versions win because they're the source of truth for the new surface tokens.
- **Est:** 3h (asset-catalog edits + spec authorship + bulk snapshot re-record + manual sim verification with screenshots).
- **||:** P10-color-overhaul

### T-500 — Search-tab polish bundle (US-29, CL-49)
- **Scope:** Five small Search-tab polish items bundled into a single PR because they all touch `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (or its `RecentSearches` helper) and the snapshot baseline churn is shared. CL-49 captures the five decisions and the AC-20.3 reversal.
  1. **"Try" pill action change (AC-29.1, also fixes the round-6 "tag search no-results" report — CL-49.1).** In `SearchView.swift`'s `case .idle:` branch of the `content` switch, the `IdleSuggestionsView`'s `onCategoryTap` closure is rewritten. Pre-T-500 the closure set both `viewModel.filters.categoryID = category.id` AND `viewModel.query = category.name`. Post-T-500 it sets only the query: `viewModel.query = category.name`. The category-filter chain (which requires a hydrated `categoryIDsByRecipe` map per `SearchFilters.swift:55-58`) is bypassed entirely — the search runs as a normal REST text query against the existing 300ms debounce path. This implicitly fixes the user-reported "tag search returns 'No recipes match'" smoking gun because the bug was the filter dropping every REST result whose recipe-detail page hadn't been cached locally yet (the WP categories taxonomy is loaded lazily and the cache hydrates on detail open, so cold-cache REST hits were filtered out wholesale).
  2. **"Clear All" button (AC-29.2).** In `IdleSuggestionsView`'s `section(title: "Recent")` builder, the section header is wrapped in an `HStack` with the "Recent" label at the leading edge and a "Clear All" button at the trailing edge. The button calls a new public `SearchViewModel.clearRecentSearches()` method that wraps `RecentSearches.clear()` (existing per `RecentSearches.swift:53-55`) and resets `recentSearches` to an empty array. Accessibility label: `"Clear all recent searches"`. The button only renders when the Recent section renders (i.e. when `recents` is non-empty); when there are no recents, the entire section is hidden per the existing `if !recents.isEmpty` guard.
  3. **`questionmark.folder` → `questionmark.circle` (AC-29.3).** In `SearchView.swift`'s `.noResults` `EmptyState` (line ~74), the `systemImage` literal changes from `"questionmark.folder"` to `"questionmark.circle"`. Title and message strings are unchanged. CL-49.3 captures the explicit AC-20.3 reversal — T-350's carve-out is overridden by user feedback that `questionmark.folder` reads as "in some folder I haven't found" rather than "not found, period."
  4. **Remove "All categories" menu row (AC-29.4).** In `FilterChipRow.categoryChip`'s `Menu { ... }` content, the `Button("All categories") { filters.categoryID = nil }` first row is deleted. The chip's label-via-`selectedCategoryName` ("All categories" when no category is picked) is preserved — that's the chip's *display*, not the menu's row. To clear a selected category, the user re-taps the same category in the menu (which deselects it via the same `filters.categoryID = category.id` setter cycling), or navigates to the Categories tab via the bottom nav.
  5. **"Try" pill action change (AC-29.1, same fix as item 1).** See item 1 — same call site, same one-line change. CL-49.5 documents that items 1 and 5 of the round-6 backlog resolve to a single action-handler change.
  **Out of bounds:** the `SearchResultMerger` ranking logic, the `SearchFilters.apply(...)` filter chain (still correct for user-driven chip toggles), the `SearchViewModel.scheduleSearch()` 300ms debounce, `SearchViewModel.performSearch()`, `RecentSearches.maxEntries` (still 10), `RecentSearches.storageKey` (still `dod.recentSearchesV1`), the telemetry contract (still `StringHasher.sha256Hex` per AC-3.6), `WPRestClient.search(query:)`, `dependencies.searchIngredients(matching:)`, the cook-time filter chip, the recently-viewed-only chip, the offline-state empty state (`wifi.slash` + "Search needs internet"), the idle-state fallback empty state (`magnifyingglass` + "Find a recipe"), the search-field's leading `magnifyingglass` icon, the search-field's trailing clear button (`xmark.circle.fill`), or the Categories tab's `.searchable` filter (different surface, US-19 territory).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-29), `specs/dod-ios-app/clarifications.md` (CL-49), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate the 5 round-6 Search-tab items into "Recently graduated").
  - **Source (commit 2):** `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (four changes: `IdleSuggestionsView.onCategoryTap` closure; `IdleSuggestionsView.section(title: "Recent")` header HStack + Clear-All button; `.noResults` `EmptyState` `systemImage`; `FilterChipRow.categoryChip` Menu's first-row deletion); `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchViewModel.swift` (one new public method `clearRecentSearches()` that wraps `RecentSearches.clear()` + resets `recentSearches`).
  - **Tests (commit 2):** `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/SearchViewModelTests.swift` (one new test: `clearRecentSearchesEmptiesStore`, mirrors `RecentSearchesTests.clearRemovesAll`'s shape); re-record any `FilterChipRowSnapshotTests` baseline whose PNG drifts (the Menu's first-row deletion sits inside the chip's expanded-menu render path which the closed-state snapshot frame may or may not catch — first test-run determines whether re-record is needed; if all four PNGs come out byte-identical, no re-record).
  - **Out of bounds:** `SearchFilters.swift`, `SearchResultMerger.swift`, `RecentSearches.swift` (existing `clear()` already does what's needed), `SearchDependencies.swift`, any `SearchResultMergerTests` / `SearchFiltersTests` / `RecentSearchesTests` test method (existing coverage suffices), any `SearchViewSnapshotTests` baseline re-record (owned by T-335 — out of scope per the same T-350 precedent).
- **AC:** AC-29.1, AC-29.2, AC-29.3, AC-29.4, AC-29.5, AC-29.6; amends AC-20.3 (the `questionmark.folder` carve-out is reversed); pins AC-3.1..AC-3.7 (US-3 not regressed), AC-12.1..AC-12.6 (US-12 not regressed).
- **Deps:** T-350 (US-20 / PR #23) — amends T-350's AC-20.3 carve-out, so requires T-350's `tag.fill` glyph change to be on `main`. Already merged.
- **Est:** 1.5h (four small source edits + one new VM method + one new VM test + snapshot baseline review + sim manual verification + PR body assembly).
- **||:** P10-search

### T-396 — Lock-screen widget readability audit (US-22, CL-47, amends AC-22)
- **Scope:** Audit-style task framed by CL-47. Parallel to T-390 but scoped to the lock-screen accessory rendering pipeline rather than the home-screen Tinted/Clear/Vibrant pipeline T-390 covered. Audit the five readability dimensions the lock-screen pipeline can break on the existing `LatestRecipeLockScreenWidget` (T-370 / PR #26 territory): (1) text truncation behavior under a worst-case 80-character title, (2) body text legibility through the system vibrancy pass, (3) empty-state copy legibility (text-only, no glyph that loses meaning under the system tint), (4) layout hugging in the system-allotted ~172×76pt frame, (5) any hardcoded `.white` / `.black` / hex colors that would render unpredictably through the wallpaper-aware tint pass. Surfaces audited: `WidgetCard.LockScreenRectangular` + `WidgetCard.LockScreenEmpty` (`Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard+LockScreen.swift`), `LatestRecipeLockScreenWidget` + `LatestRecipeLockScreenWidgetEntryView` + `LatestRecipeLockScreenTimelineProvider` (`Widget/LatestRecipeLockScreen*.swift`). **Audit outcome (CL-47 explicitly authorizes a clean audit as a valid outcome — mirrors CL-39's framing for T-390):** the existing implementation meets the readability bar on all five dimensions without source changes. Findings inventory: (1) `Text(content.title).lineLimit(2)` is present on `LockScreenRectangular.body`; SwiftUI's default truncation mode is `.tail` and the existing L4 long-title baseline (`test_lockScreenWidget_rectangular_populated_longTitle`) renders cleanly with a trailing ellipsis — no mid-word truncation. (2) No `.foregroundStyle` / `.foregroundColor` overrides anywhere in the lock-screen surface — text inherits `.primary` from `.font(.system(.caption2/.headline/.caption, ...))` which the system vibrancy pass interprets as tintable content. (3) `LockScreenEmpty` renders three text lines ("LATEST RECIPE" / "Dutch Oven Daddy" / "Open the app to see the latest recipe.") with no glyphs — semantic copy survives the monochrome tint. (4) `VStack(alignment: .leading, spacing: 2) { ... }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)` on both `LockScreenRectangular` and `LockScreenEmpty` top-anchors the content and fills the system-allotted ~172×76pt frame without overflow. (5) Single `Color.clear` in `LatestRecipeLockScreenWidget.body`'s `containerBackground(for: .widget)` closure — that's the documented signal to defer to the system's `AccessoryWidgetBackground` rendering pass, not a paint operation. Zero hardcoded `.white` / `.black` / hex literals on any rendered surface. **Manual wallpaper verification:** the lock-screen pipeline's wallpaper-aware tinting cannot be snapshot-tested through environment injection (the system applies the tint at present-time against the user's actual wallpaper, not at render-time against an injected environment value), so the audit's primary contrast evidence is a manual sim pass: install the widget on iPhone 17 simulator, lock the sim (Cmd+L), cycle through three reference Lock Screen wallpapers (dark wallpaper, light wallpaper, photo wallpaper), confirm text stays legible in all three. The PR body documents which three wallpapers were exercised. **Snapshot baselines:** no re-record needed — the existing three baselines (`test_lockScreenWidget_rectangular_populated`, `test_lockScreenWidget_rectangular_populated_longTitle`, `test_lockScreenWidget_rectangular_empty`) lock the *layout* and are unchanged by a no-source-touch audit. **Fix authority (clean audit means none used, but the framing carries it):** if a future re-run surfaces a failure, the authorized fixes per CL-47 are (a) replace any hardcoded color with `.primary` / `.secondary` / `.tint`, (b) add `.widgetAccentable(true)` on a key element that should pick up the system tint, (c) tighten line limits + add explicit `.truncationMode(.tail)`, (d) add a contrast scrim — all bounded to the listed lock-screen-widget files. **Why no fix lands now:** the implementation shipped with T-370 was designed to the readability constraints from the start (text-only, semantic typography, `.widgetAccentable()` on the entry view, no hardcoded colors), so a clean audit is the expected outcome, not a surprise. **Coordination note:** T-394 and T-395 are parallel widget-surface audits running on different branches at the same time; spec-file collisions are expected at merge time and the rebaser picks the next free CL slot.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (AC-22.6 added), `specs/dod-ios-app/clarifications.md` (CL-47), `specs/dod-ios-app/tasks.md` (this entry).
  - **Source (commit 2):** none — clean audit per CL-47.
  - **Tests (commit 2):** none — existing `LockScreenWidgetSnapshotTests` baselines (`__Snapshots__/LockScreenWidgetSnapshotTests/test_lockScreenWidget_rectangular_{populated,populated_longTitle,empty}.1.png`) are unchanged by a no-source-touch audit.
  - **Out of bounds:** `Widget/FeaturedRecipeWidget*.swift` (US-9 / US-21 home-screen widget — different rendering pipeline, T-390 covered it), `Widget/SavedRecipesWidget*.swift` (US-17 home-screen widget — different rendering pipeline, T-390 covered it), `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` / `WidgetCard+Saved.swift` (home-screen variants — same pipeline scoping), the `WidgetSnapshot` wire format (AC-22.2 contract), the `widgetURL` grammar (AC-22.3 contract), the `LatestRecipeLockScreenTimelineProvider` cadence (the 4-hour refresh + `reloadAllTimelines()` preempt path is the US-22 contract), the L4 baselines themselves (a clean audit means the rendered layout is unchanged byte-for-byte).
- **AC:** AC-22.6 (new); pins AC-22.1, AC-22.2, AC-22.3, AC-22.4, AC-22.5 (existing US-22 contract unchanged by a clean audit).
- **Deps:** T-370 (US-22 / PR #26) — audits T-370's shipped implementation. Already merged.
- **Est:** 1h (audit pass + manual wallpaper verification + spec commit; clean-audit outcome means no source-touch second commit).
- **||:** P10-lock-screen-audit

### T-510 — New-recipe surfacing: bypass URLCache + Cloudflare CDN on every WP REST call (REG-18, CL-50)
- **Scope:** Two-line fix to `WPRestClient.get(path:queryItems:)` at `Packages/DODNetworking/Sources/DODNetworking/WPRestClient.swift` per CL-50. Sets `request.cachePolicy = .reloadIgnoringLocalCacheData` (bypasses iOS `URLCache.shared`) AND `request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")` (asks Cloudflare's edge CDN to revalidate with origin per RFC 7234 §5.2.1.4) on the `URLRequest` before handing it to `httpClient.data(for:)`. Both lines are required: cachePolicy alone bypasses the device-side cache but lets the CDN serve a stale edge copy; the header alone tells the CDN to revalidate but leaves URLCache.shared serving stale entries on the device side. The change lives in the shared `get(...)` helper so all WP REST surfaces (`posts()`, `categories()`, `search()`, `comments()`, `ratings()`) benefit identically — pushing the decision down to the HTTP-client seam keeps every call site correct by construction. **Why not opt-in:** CL-50 considered + rejected a `forceFresh: Bool` parameter on `WPRestClient.posts()` that `FeedViewModel.refresh()` would set — that invites the bug to come back in any future call site that forgets the flag. **Why not a cache-busting query param (e.g., `_t=<unix-ms>`):** verified to force CDN miss (`curl '...?_t=12345'` returns `cf-cache-status: MISS`), but pollutes Cloudflare's cache with a unique key per request and defeats the CDN's value for non-app HTTP clients hitting the same origin; `Cache-Control: no-cache` revalidates this specific request while preserving the cache for everyone else. **Why not `.reloadIgnoringLocalAndRemoteCacheData`:** adds `Pragma: no-cache` (HTTP/1.0 compat) on top of `Cache-Control: no-cache`; Cloudflare honors both but the extra header adds no signal and clutters trace readability. **Why not `.reloadRevalidatingCacheData`:** that policy revalidates via `If-Modified-Since`, but Cloudflare's `304 Not Modified` response still comes from the edge cache, not origin — same staleness problem. **Why not `URLCache.shared = URLCache(memoryCapacity: 0, ...)` globally:** would also disable URLCache for `ImageLoader`'s hero-image fetches where CDN-cached image bytes are *desirable*; per-request opt-out keeps the global cache useful for surfaces that should use it. **What this task does NOT touch:** `WPRestClient`'s decoder shape, the `WPDTO` family, `RecipeStore.cache(listItem:)` / `RecipeStore.listItems(forIDs:)`, `FeedViewModel.loadInitial(forceReplace:)` / `FeedViewModel.refresh()`, the blocklist clearing path (AC-1.7 unchanged), `LiveFeedDependencies.publishWidgetSnapshot(items:)` and the CL-45 / T-362 image-prefetch flow (image bytes still arrive via `ImageLoader` + `RecipeStore.cacheImage(url:bytes:)`; `ImageLoader` uses its own `URLSession` instance separate from `WPRestClient.get(...)` and keeps its HTTP cache behavior intact — verified by inspection that no production `ImageLoader` callsite uses the same URL space). **Test:** new L2 test `feedRefreshBypassesStaleURLCacheEntry` appended to the existing `LiveAPITests` suite in `Packages/DODIntegrationTests/Tests/DODIntegrationTestsTests/LiveAPITests.swift`. The test plants a known-stale `CachedURLResponse` in `URLCache.shared` for the exact production URL `WPRestClient.posts()` requests (the JSON body is `[]` — empty array — which round-trips through `WPRestClient.posts()` into an empty `[RecipeListItem]`), with headers `Cache-Control: max-age=3600` + `Last-Modified: <some-fresh-date>` so URLSession would serve it under `.useProtocolCachePolicy`. Then calls `WPRestClient.posts()` and asserts the returned list is non-empty — fails on `origin/main` (URLSession serves the planted empty-array decoy from `URLCache.shared`), passes after the two-line fix (URLSession bypasses URLCache and hits the network for the real post list). The test inherits the suite's `.enabled(if: ProcessInfo.processInfo.environment["DOD_RUN_LIVE_TESTS"] == "1")` gate so PR CI skips it and the nightly job picks it up — same shape as REG-2 / REG-13 / REG-14 / REG-16. `defer { URLCache.shared.removeCachedResponse(...) }` cleans up so the test doesn't leak across runs. **Out of bounds:** `Packages/DODNetworking/Sources/DODNetworking/WPCommentsClient.swift` (uses its own `URLSession` instance per WPCommentsClient.swift inspection, not `WPRestClient.get(...)`; commentary in CL-50 notes this isn't a concern because comments-list updates are user-driven via the composer post-submit reload and the staleness window doesn't accumulate the same way the feed-refresh pattern does), `Packages/DODNetworking/Sources/DODNetworking/WPRMRatingsClient.swift` (likewise uses its own session), the `ImageLoader` URLSession (image bytes are immutable per URL — staleness isn't possible because a different image gets a different URL), the `RecipePageFetcher` (used for JSON-LD detail fetches via the post's `link` URL, NOT via the WP REST API — separate code path; staleness of the post HTML is owned by the same origin's WP page cache, not the WP REST cache, and a separate concern this task doesn't address), the `WPRestClient.posts()` query-param construction (still passes `page` + `per_page` + `_embed=wp:featuredmedia`, unchanged), the `defaultPageSize` constant (still 20 per CL-2), the test pyramid `AC-T1..T3` mandates (REG-18 follows AC-T4's "regression test in the same PR as the fix" pattern verbatim).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (REG-18 bullet appended under Test pyramid after REG-16), `specs/dod-ios-app/clarifications.md` (CL-50), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate "New-recipe surfacing" under "Recently graduated").
  - **Source (commit 2):** `Packages/DODNetworking/Sources/DODNetworking/WPRestClient.swift` — two-line addition inside `get(path:queryItems:)` (after `request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")` and before the `httpClient.data(for: request)` call). Diff is bounded to ~5 lines including the inline comment explaining REG-18.
  - **Tests (commit 2):** `Packages/DODIntegrationTests/Tests/DODIntegrationTestsTests/LiveAPITests.swift` (one new test method `feedRefreshBypassesStaleURLCacheEntry` appended to the existing `LiveAPITests` suite — same file as REG-2 / REG-13 / REG-14 / REG-16's test methods). No new `Package.swift` dependency adds (the test uses `URLCache.shared` from Foundation, which DODIntegrationTests already imports).
  - **Out of bounds:** `Packages/DODFeatureFeed/**` (the view-model + view code is correct as-is; the L2 test proves this since T-420), `Packages/DODPersistence/**` (the store path is correct as-is per T-420's REG-16), `App/**` (composition root is unchanged — `WPRestClient` is constructed the same way), `Widget/**` (widget paths don't touch `WPRestClient.get(...)`), `.github/workflows/nightly-live-api.yml` (existing job picks up the new method automatically per the `swift test --parallel` invocation), `.github/workflows/ci.yml` (REG-18 stays nightly-only per AC-T3).
- **AC:** Implements US-1 AC-1.4 (pull-to-refresh shows newly published recipes — the failure surface the bug reports against); locked by REG-18 (US-1, T-510); pins AC-T3 (nightly-only L2 tier), AC-T4 (regression test in same PR as the fix), AC-1.1 (newest posts surface in home feed). Does not add new acceptance criteria — this is a regression-tier entry under the existing Test pyramid section, same pattern T-420's REG-16 followed (no new US, no new AC, just a new REG bullet + a named live-API test).
- **Deps:** — (independent; runs against current main with T-420 / REG-16 already merged providing the LiveAPITests scaffolding). Parallel with T-500 (Search-tab polish, round-6 backlog) and T-520 (color overhaul, round-6 backlog); no code conflicts expected — T-500 touches `Packages/DODFeatureSearch/**`, T-520 touches the `DODColor` asset catalog + design-system tokens, T-510 touches `Packages/DODNetworking/Sources/DODNetworking/WPRestClient.swift` + `Packages/DODIntegrationTests/Tests/DODIntegrationTestsTests/LiveAPITests.swift`. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL slot (T-510 reserved CL-50; T-500 may have taken CL-49).
- **Est:** 2h (root-cause investigation + two-line source fix + L2 test authoring + manual sim verification + spec/CL/tasks/backlog commit + PR body assembly).
- **||:** P10-livetests (same cluster as T-420 — both touch `LiveAPITests`).

### T-440 — Recipe detail per-render serving-count scaling (US-31, CL-52)
- **Scope:** Add a "Serves N" stepper to `RecipeDetailView` immediately under the existing `RecipeDetailMetaPills` row that scales ingredient quantities at render time without mutating the source `Recipe` model. The stepper binds to a new `RecipeDetailViewModel.userServings` integer (range `1...24`, default = source `recipeYield` from JSON-LD per AC-4.11, fallback `RecipeDetailViewModel.defaultServings = 4` when the recipe hasn't loaded yet or didn't publish a yield). The view-model exposes `servingsScaleFactor` (= `Double(userServings) / Double(sourceServings)`) and `shouldShowServingWarning` (= `FractionRenderer.shouldShowDutchOvenWarning(forServings: userServings)`, returns true when > 12). The view's ingredient `ForEach` body passes the scaled text through `IngredientCheckRow.displayText` via `FractionRenderer.scale(ingredient.text, by: factor)`. The new `FractionRenderer` utility lives in `Packages/DODSupport` so `CookModeView.ingredientsDrawer` can consume the same scale factor (the host passes `viewModel.servingsScaleFactor` as `ingredientScaleFactor` to `CookModeView.init` — the new parameter defaults to `1.0` so existing call sites stay unbroken). The renderer snaps to the eighth-cup canonical set `{1/8, 1/4, 1/3, 1/2, 2/3, 3/4, 7/8}` + whole numbers with a 1/16 tolerance per CL-52, and falls back to two-decimal rendering only for sub-tolerance remainders with a zero whole (rare). Lines without a leading quantity (`"Salt and freshly ground black pepper (to taste)"`) pass through verbatim — the parser never invents a quantity. The non-blocking warning caption (`"Most home dutch ovens (5-quart) cap out around 12 servings. Consider doubling the recipe in two batches instead."`) renders below the stepper when `userServings > 12` with an `exclamationmark.triangle.fill` glyph in `DODColor.burntOrange`. The source `Recipe.servings` integer and `RecipeIngredient.text` string are never mutated — scaling is pure presentation (AC-31.8). **Out of bounds:** any `Recipe` / `RecipeIngredient` schema change (the JSON-LD parse is the contract per AC-4.11; the renderer parses the leading quantity from the single free-text `ingredient.text` field without needing structured amount/unit decomposition), any `RecipeStore` change (the cache stores the source recipe untouched), any new analytics event (no `recipeScaled` telemetry — out of scope per CC-5), any new deep-link case (the deep-link grammar covers recipe / feed / saved tabs, scaling is local to the view), any `WidgetSnapshot` field add (the widget surfaces source-yield recipes, never scaled), any persistence of `userServings` across screen visits (v1 resets on screen exit — a clean v1.x follow-up if user-testing surfaces a habitual-scale pattern).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-31, AC-31.1..AC-31.8), `specs/dod-ios-app/clarifications.md` (CL-52), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate "Recipe scaling" under "Recently graduated").
  - **Source (commit 2):** `Packages/DODSupport/Sources/DODSupport/FractionRenderer.swift` (new — ~190 LOC enum with `scale(_:by:)` + `renderQuantity(_:)` + `dutchOvenServingWarningThreshold` constant + `shouldShowDutchOvenWarning(forServings:)` helper); `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailViewModel.swift` (add `userServings`, `userServingsRange`, `defaultServings`, `sourceServings`, `servingsScaleFactor`, `shouldShowServingWarning`, `setUserServings(_:)`, `resetServingsToSourceIfFirstLoad()`, `clampToRange(_:)` — additive, no existing API changes); `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` (insert `servingsScaler` view in `readyBody` between `RecipeDetailMetaPills` and `cookNowSection`; thread `displayText: FractionRenderer.scale(...)` through `IngredientCheckRow` in `ingredientsSection`; thread `ingredientScaleFactor: viewModel.servingsScaleFactor` through `CookModeView.init` in `cookModeCover`; call `viewModel.resetServingsToSourceIfFirstLoad()` from `handleLoadStateChange` when the load state transitions to `.ready`); `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/IngredientCheckRow.swift` (additive `displayText: String? = nil` parameter on `init`, defaulted to `nil` so it falls back to `ingredient.text` for existing call sites); `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeView.swift` (additive `ingredientScaleFactor: Double = 1.0` parameter on `init`; threads through to the `ingredientsDrawer` `ForEach` body where it wraps `ingredient.text` in `FractionRenderer.scale(...)`); `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeServingsScaler.swift` (new — the stepper + secondary-line + warning-caption view).
  - **Tests (commit 2):** `Packages/DODSupport/Tests/DODSupportTests/FractionRendererTests.swift` (new — 26 Swift Testing test methods using `@Suite("FractionRenderer")` covering the four backlog-quote load-bearing cases, decimal-source snap, integer/fraction/decimal/mixed parse-precedence, factor-of-1 short-circuit, zero-factor verbatim, the canonical-fraction-set snap table, `renderQuantity(_:)` direct calls, and the warning-threshold boundary at 12/13); `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/RecipeDetailViewModelTests.swift` (8 new `@Test` methods appended to the existing `RecipeDetailViewModel (T-110..T-121)` suite covering default-fallback, source-yield sync, no-op-after-manual-change, range clamping, scale-factor at half/double, warning kick-in, AC-31.7 check-state survival, AC-31.8 source-recipe immutability); `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/RecipeServingsScalerSnapshotTests.swift` (new — 6 L4 baselines: default = 4 servings, scaled-up = 8 servings, warning-threshold = 16 servings, each in light + dark via `UITraitCollection(userInterfaceStyle:)` + `.preferredColorScheme(...)` — same pattern `TabBarSnapshotTests` uses); `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/FakeRecipeDetailDependencies.swift` (additive `servings: Int? = nil` + `ingredients: [RecipeIngredient]? = nil` parameters on `RecipeDetailTestFixtures.makeRecipe(...)` so tests can pin `recipeYield` and exact ingredient text — defaults preserve existing call-site behavior). 6 baseline PNGs under `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/__Snapshots__/RecipeServingsScalerSnapshotTests/`.
  - **Out of bounds:** `Packages/DODDomain/**` (no `Recipe` / `RecipeIngredient` schema change — the source model stays a contract baked into AC-4.11), `Packages/DODPersistence/**` (no `RecipeStore` change — the cache stores source recipes, scaling is at render time), `Packages/DODNetworking/**` (no JSON-LD parser change — the renderer consumes the existing `ingredient.text` field), `Packages/DODAnalytics/**` (no `recipeScaled` analytics event — out of scope per CC-5; if user testing surfaces a pattern that justifies a new event, that's a clean v1.x follow-up under constitution §9), `Widget/**` (widgets render source-yield recipes, never scaled — there's no widget surface that shows ingredient text today, and a future surface that did would consume the scaler the same way the recipe-detail view does), `Packages/DODFeatureSaved/**` / `Packages/DODFeatureFeed/**` / `Packages/DODFeatureSearch/**` / `Packages/DODFeatureCategories/**` (no list-surface change — the lists render hero + title + excerpt, no ingredient text), `App/**` (no composition-root change — `FractionRenderer` is a pure utility with no init / dependency-injection footprint).
- **AC:** Implements US-31 AC-31.1..AC-31.8. Pins AC-4.1 (the existing meta row is unchanged — the stepper sits directly under it without altering its content), AC-4.2 (ingredient checkbox + strikethrough state survives a scale per AC-31.7), AC-4.11 (the JSON-LD `recipeYield` integer is the default source for `userServings`; the source `Recipe.servings` is never overwritten), AC-7.5 (the Cook Mode drawer surfaces the same scaled quantities via the threaded `ingredientScaleFactor`, so check state and quantity rendering agree across the screen pair). Locks no new REG entry — this is presentation logic; the regression net for the renderer's math is the L1 `FractionRendererTests` suite, and the visual contract is the L4 `RecipeServingsScalerSnapshotTests` baselines.
- **Deps:** — (independent; runs against current main). Parallel with T-530 (Any-time filter composition, round-6 backlog) on `feat/T-530-any-time-filter-composition`; the two PRs touch completely independent code paths (Search vs Recipe Detail) so no source-file collisions are expected. Spec-file conflicts at merge time (both branches add a new CL entry and a new US entry) are normal — the prompt for T-440 fixed CL-52 / US-31 for this branch; T-530's spec commit will pick the next free slot.
- **Est:** 3h per the round-3 backlog size (S, "~3 days"); actual scope here lands closer to 2–2.5h thanks to the renderer being a pure utility with golden L1 tests and the view changes being additive (no existing API breaks).
- **||:** P10-detail-scaler (new P10 cluster slot — independent of P10-search / P10-livetests / P10-detail-cleanup / P10-widget-appearance).

### T-530 — "Any time" filter + category filter compose AND-wise for fresh REST results (REG-17, CL-53)
- **Scope:** Round-6 backlog item 6 fix — picking a duration in the Any-time chip should narrow results in combination with a category filter ("Beef and Red Meat Recipes that take ≤1 hour"). Root cause traced in CL-53: WP REST `/wp/v2/posts?search=...` returns `Post.categories: [Int]` on every search hit, but `WPDTO.Post.toRecipeListItem(heroImage:)` at `WPDTOs.swift:235` drops those category IDs at the network → domain boundary, and `RecipeStore.cache(listItem:)` never writes `categoryIDs` to the cache row. So `RecipeStore.categoryIDs(forRecipeIDs:)` returns `[recipeID: []]` for every fresh REST hit whose detail page hasn't yet been opened, and `SearchFilters.apply(...)` line 56's `categoryIDsByRecipe[item.id]?.contains(categoryID) == true` check resolves to `false` for `[]?.contains(10)` — dropping every fresh REST hit before the cook-time chip's predicate ever runs. The user reads this as "the Any-time chip didn't compose with the category chip" because layering the cook-time predicate on top of an already-empty set yields zero. **Fix (REG-17):** propagate the WP categories taxonomy already-on-the-wire through the same `cache(listItem:)` path REST results take. Concretely: (1) add an optional `categoryIDs: [Int]?` field to `DODDomain.RecipeListItem` (Optional with default `nil` so existing Codable payloads — widget snapshots, recipe-list JSON caches — decode cleanly; same backward-compat pattern `canonicalURL` / `heroImage` / `totalTimeDisplay` use). (2) Populate it from `WPDTO.Post.categories` inside `WPDTO.Post.toRecipeListItem(heroImage:)`. (3) Update `RecipeStore.cache(listItem:)` to write `listItem.categoryIDs` through to `CachedRecipe.categoryIDs` on both the update and the insert branches, guarded by `if let categoryIDs = listItem.categoryIDs, !categoryIDs.isEmpty` so a nil/empty wire value doesn't clobber an existing populated array (mirrors the existing `canonicalURL` guard at `RecipeStore.swift:32-34`). The cook-time filter still requires a JSON-LD parse to populate `CachedRecipe.totalSeconds` (documented MISS behavior per `RecipeStore+IngredientIndex.swift:84-87`) — that semantic is preserved. After the fix, picking "Beef and Red Meat" narrows the result set to the category-tagged REST hits (using wire data already in flight), then picking "≤1 hour" narrows further to those whose totalSeconds is populated AND ≤3600 — AND composition end-to-end, no extra network round-trip, no schema change. **Why not pre-hydrate categoryIDsByRecipe on chip toggle:** CL-49.1 already documented this as rejected — adds a per-toggle network round-trip the WP categories taxonomy doesn't directly support per-post. The wire-data-already-in-flight approach is the cleanest seam. **Why not non-optional `categoryIDs: [Int]` with default `[]` on `RecipeListItem`:** breaks Codable decode of pre-CL-53 widget snapshots and cached payloads — Optional with default `nil` is the safe path the existing fields use. **Why the `cache(listItem:)` guard preserves a populated `categoryIDs` over a nil/empty wire value:** mirrors the `canonicalURL` guard's documented rationale ("Only overwrite when a non-empty value is available so we don't clobber a good existing value with an empty one") — a row that was hydrated via `mergeDetail(_:)` (post-JSON-LD parse) shouldn't have its category data wiped if a subsequent feed-refresh REST hit happens to come back with an empty categories array (server-side glitch, plugin misconfiguration). **What this task does NOT touch:** `SearchFilters.apply(...)` (the chain stays AND-wise; fixing the data input, not the filter logic), `SearchResultMerger.merge(...)` (ranking + dedupe stays correct — REG-12 locks it), `SearchViewModel.performSearch()` flow (still REST + local + merge + filter; the change is invisible at this layer because the cache pass now propagates one more field), the 300ms debounce (AC-3.1 unchanged), the telemetry hash contract (AC-3.6 unchanged), `RecipeStore.mergeDetail(_:)` (still the JSON-LD-driven update path for the full recipe detail), the `CachedRecipe` SwiftData schema (the existing `var categoryIDs: [Int] = []` field stays — no migration, no schema bump, additive value-only write path), the `searchIngredients(matching:)` local index (US-12 / AC-12.1 contract unchanged), the cook-time bucket semantics (`CookTimeBucket.contains(totalSeconds:)` unchanged), the "Recently viewed" chip (independent filter slice), the offline graceful-degradation behavior (`offlineWithLocalIngredientHitsStillShowsResults` still passes — categories don't gate the local ingredient pass), the existing snapshot baselines (no view change, no chip layout change). **Test (REG-17):** new `composeCategoryAndCookTimeFiltersForFreshRESTResults` in `SearchResultMergerTests`. Sets up two recipes both in category 10, one with `totalSeconds: 25 * 60`, one with `totalSeconds: 90 * 60`. Runs the merger, applies `filters = {categoryID: 10, cookTime: .under60}`, asserts only the under-60 recipe survives. Second assertion swaps `cookTime: .under15` and asserts neither survives. The contract is the AND composition pinned to AC-12.3 for fresh REST results. Companion store-side test `RecipeStoreCategoryIDsRoundTripFromListItem` in `Packages/DODPersistence/Tests/DODPersistenceTests/SearchIndexTests.swift`'s `SearchFilterInputsTests` suite caches a `RecipeListItem` with `categoryIDs: [10, 20]` and asserts `categoryIDs(forRecipeIDs: [id])[id] == [10, 20]` without ever calling `mergeDetail`. Companion network-side assertion appended to `WPRestClientPostsTests.decodesAndMapsToRecipeListItem` checks `item.categoryIDs == [1590, 334]` against the existing fixture. **Manual verification:** sim Search tab, search "beef", tap a category chip (e.g. "Beef and Red Meat"), confirm results narrow; tap the Any-time chip, pick "≤1 hour," confirm results narrow further. Screenshot before + after the filter for the PR body. **Coordination note:** T-440 (Recipe Scaling) is running on a parallel branch in this same round; T-440's diff is recipe-detail-only so source-side collision is zero. Spec-file collisions at merge time on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected and the rebaser picks the next free CL slot.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (REG-17 bullet appended under Test pyramid after REG-18), `specs/dod-ios-app/clarifications.md` (CL-53), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate the "Any time filter actually composes with other filters" entry under round-6 → "Recently graduated").
  - **Source (commit 2):** `Packages/DODDomain/Sources/DODDomain/RecipeListItem.swift` (one new Optional `categoryIDs: [Int]?` stored property + `init` parameter with default `nil`); `Packages/DODNetworking/Sources/DODNetworking/WPDTOs.swift` (one-line addition to `WPDTO.Post.toRecipeListItem(heroImage:)`: `categoryIDs: categories`); `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (guarded write of `listItem.categoryIDs` to `CachedRecipe.categoryIDs` on both the update branch and the insert-initializer call inside `cache(listItem:)`).
  - **Tests (commit 2):** `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/SearchResultMergerTests.swift` (one new test `composeCategoryAndCookTimeFiltersForFreshRESTResults`); `Packages/DODPersistence/Tests/DODPersistenceTests/SearchIndexTests.swift` (one new test `categoryIDsRoundTripFromListItem` in `SearchFilterInputsTests`); `Packages/DODNetworking/Tests/DODNetworkingTests/WPRestClientTests.swift` (one new assertion appended to `decodesAndMapsToRecipeListItem` for `item.categoryIDs == [1590, 334]`).
  - **Out of bounds:** `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (no view change), `SearchViewModel.swift` (no flow change), `SearchFilters.swift` (chain stays AND-wise), `SearchResultMerger.swift` (ranking + dedupe stays correct), `RecentSearches.swift`, `SearchDependencies.swift` (protocol contract unchanged — the `categoryIDs(forRecipeIDs:)` method now returns populated data for fresh REST hits, but the signature is byte-identical), `Packages/DODPersistence/Sources/DODPersistence/CachedRecipe.swift` (the `var categoryIDs: [Int] = []` field already exists per US-12 / CL-19), `Packages/DODPersistence/Sources/DODPersistence/SchemaV3.swift` (no schema bump — additive write path on an existing field), the widget snapshot wire format (`WidgetSnapshot` uses its own `Entry` struct, not `RecipeListItem` directly — Optional categoryIDs on `RecipeListItem` doesn't propagate into widget snapshots), the WP REST `/wp/v2/posts` request shape (unchanged — `categories` is already in the response, no query-param change), the telemetry contract (`AC-3.6` unchanged — query hashing path untouched), every existing snapshot baseline (no view change, no chip layout change), `RecipeStore.mergeDetail(_:)` (still the JSON-LD-driven detail merge; the categories assignment at line 92 stays — when the user opens a detail page, the JSON-LD parse's categories array is merged in exactly as before, and the existing `recipe.categoryIDs.isEmpty ? target.categoryIDs : recipe.categoryIDs` guard preserves the REST-supplied categories if the detail parse happens to surface an empty array).
- **AC:** Implements US-12 AC-12.3 (filters compose without network — REG-17 is the AC-12.3 lock for *fresh REST results*, complementing REG-12's broader US-12 coverage); pins AC-12.1 (ingredient-aware ranking unchanged), AC-12.2 (filter chips unchanged), AC-12.4 (recent + suggestions unchanged), AC-12.5 (<200ms local search unchanged), AC-12.6 (unit tests on merger — REG-17 adds the composition contract); pins AC-3.1 (300ms debounce), AC-3.6 (hashed telemetry), AC-3.7 (offline), AC-T4 (regression test in same PR as fix). Does not add new acceptance criteria — this is a regression-tier entry under the existing Test pyramid section, same pattern T-510's REG-18 followed.
- **Deps:** T-500 (US-29 / CL-49) already merged — provides the user-driven category-chip surface this fix complements. Parallel with T-440 (Recipe Scaling, recipe-detail-only); no source collisions expected. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL slot (T-530 reserved CL-53; T-440 may have taken CL-52).
- **Est:** 2h (root-cause investigation + three-file source fix + three test additions + manual sim verification + spec/CL/tasks/backlog commit + PR body assembly).
- **||:** P10-search (same cluster as T-350 + T-500 — touches `Packages/DODFeatureSearch/**` test files; touches `Packages/DODDomain/`, `Packages/DODNetworking/`, `Packages/DODPersistence/` sources for the wire → domain → cache pipeline fix).

### T-560 — Categories tab color consistency: revert T-430's brown override (US-24 amended, CL-54)
- **Scope:** Spec-level amendment + one-token source swap that retires the `castIronBrown` surface override T-430 (PR #32) applied to `CategoryListView` in favour of the post-T-520 `DODColor.surface` token. CL-54 captures the supersession: T-430's brown was a brand-cohesion fix authored against the pre-T-520 world (when `DODColor.surface` was the iOS-stock grouped fill — light `#FAF6EE` / dark `#1B140E` — and Categories was the only tab whose backdrop didn't read as part of the brand palette). T-520 (US-30 / CL-51) then re-tinted `Surface` and `SurfaceElevated` globally to the user-specified hex values (`#F9F6EF` light / `#42210B` dark for `Surface`; `#FFFFFF` light / `#281F19` dark for `SurfaceElevated`), pulling every tab's backdrop into the warm brown-tinted palette CL-44 was trying to reach for one tab in isolation. With T-520 on `main`, the T-430 override is no longer the brand-cohesion fix — it's the source of brand *inconsistency* (Categories sits on `castIronBrown` `#3D2B1F` while Feed / Saved / Search sit on the new `Surface` token). T-560 swaps the token so Categories joins the same `surface`-based treatment every other top-level tab already uses. **Source diff:** in `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift`, change line 93 from `.background(DODColor.castIronBrown)` to `.background(DODColor.surface)`. The `.scrollContentBackground(.hidden)` on line 92 stays — `.insetGrouped`'s default fill is `UIColor.systemGroupedBackground` (an iOS-system color, not one routed through the asset catalog's `Surface` colorset), so suppressing it remains necessary for the brand `surface` token to actually paint the surround. The row cells keep their system-default fill (`UIColor.secondarySystemGroupedBackground`), the same two-tier treatment Feed / Saved / Search inherit via `.background(DODColor.surface)` on their screen-level container plus SwiftUI-managed cards inside. **Why not delete both modifiers and let the system path render:** the `.insetGrouped` system surround paints from `UIColor.systemGroupedBackground` (iOS-stock cream in light, near-black in dark), NOT from the asset-catalog `Surface` colorset — verified by re-recording the snapshot baselines with both modifiers removed and confirming the surround rendered as iOS-system grey/black, not the brand `#F9F6EF` / `#42210B`. So the simpler "delete both lines" diff would not match Feed / Saved / Search. **Why not paint `DODColor.surfaceElevated` on the cells too:** the system default cell fill is already appearance-appropriate (near-white in light, dark near-black in dark) and contrasts the `surface` surround correctly. Forcing `surfaceElevated` via `.listRowBackground(...)` would add a second explicit token reference where the system default already plays the same role — the smaller diff (one-token swap on the surround only) matches the Feed / Saved / Search pattern exactly. **Why not amend US-24 itself:** the user-facing story intent ("Categories should feel like the rest of the app, not a system-grey detour") is preserved — it's the *means* of getting there that shifted. Only AC-24.1 names the override directly and gets struck through + amended; AC-24.2..AC-24.6 stay valid because they were always framed against the system-default cells + accessibility-preserving choices that T-560 preserves. **Snapshot baseline re-record:** all six existing `CategoryListViewSnapshotTests` PNGs are re-recorded (iPhone 13 light + dark at default Dynamic Type, iPhone 13 light + dark at AX5, iPad 12.9" light + dark at default Dynamic Type — the matrix T-340 established and T-430 re-recorded with brown). The surface color affects every PNG; reviewer pages through each one visually before commit to confirm the Categories tab now matches Feed / Saved / Search in both light and dark mode. **Manual sim verification (required per the T-520 lesson):** install fresh build on iPhone simulator `45A10D1F-36EB-452D-9ACE-5A759DA6D72D`, cycle through the four primary tabs (Recipes / Categories / Search / Saved) in light mode, switch to dark, repeat. Confirm Categories' backdrop now matches the other three tabs in both appearances. Screenshot the Categories tab for the PR body.
- **Files:**
  - **Spec/clarifications/tasks (commit 1):** `specs/dod-ios-app/spec.md` (AC-24.1 amended with strikethrough + new wording), `specs/dod-ios-app/clarifications.md` (CL-54 appended after CL-50), `specs/dod-ios-app/tasks.md` (this entry under Phase 10).
  - **Source (commit 2):** `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift` — one-token swap on line 93 (`.background(DODColor.castIronBrown)` → `.background(DODColor.surface)`) plus refreshed inline doc-comment block (lines 14-21) so the comment names the new `surface` contract rather than the retired `castIronBrown` one.
  - **Tests (commit 2):** `Packages/DODFeatureCategories/Tests/DODFeatureCategoriesTests/__Snapshots__/CategoryListViewSnapshotTests/*.png` — six re-recorded baselines. No source change to `CategoryListViewSnapshotTests.swift` itself; the existing test methods use `record: .missing`, so the re-record happens by deleting the existing PNGs, re-running the test, and committing the regenerated artifacts.
  - **Out of bounds:** `CategoryListViewModel` (no flow change), `CategoryRecipesView` (different screen, out of scope — its baselines stay untouched), the L1 `CategoriesTests.filtered(...)` unit-test suite (no logic change), the `DODColor` enum or its asset catalog (no token edits — T-520 already shipped the surface re-tint that makes this revert work), the `castIronBrown` token itself (still used by `RecipeCard.swift:104`'s time chip, `OfflineBanner`, `Snackbar`, and the Search filter chip — those call sites are untouched), any other tab's source (Feed / Saved / Search each maintain their own surface treatments, which inherit `DODColor.surface` post-T-520 by-construction), `bin/format.sh` / `swiftlint.yml`, any `xcassets` file, the `WidgetSnapshot` wire format, the deep-link grammar, any analytics event, the snapshot test method definitions themselves.
- **AC:** Amends AC-24.1 (the `castIronBrown` override wording is struck through and replaced with the post-T-520 "uses default Surface/SurfaceElevated tokens" contract per CL-54). Pins AC-24.2 (system-default cells), AC-24.3 (`.searchable` legibility — now even simpler because the field sits on the standard system grouped surround), AC-24.4 (US-2 + US-19 not regressed), AC-24.5 (six baselines re-recorded), AC-24.6 (accessibility — preserved). Pins AC-2.1..AC-2.5 (US-2 list contract not regressed), AC-19.1..AC-19.6 (US-19 layout not regressed). Pins AC-30.1..AC-30.5 (the T-520 contract this revert depends on — `Surface` / `SurfaceElevated` token values are unchanged here, just consumed by one more surface).
- **Deps:** T-430 (US-24 / CL-44 / PR #32) — reverts T-430's `.scrollContentBackground(.hidden) + .background(DODColor.castIronBrown)` source addition. T-520 (US-30 / CL-51) — depends on T-520's re-tinted `Surface` / `SurfaceElevated` tokens being on `main` so the system-default `.insetGrouped` path resolves to brand colors. Both already merged. Parallel with T-570 (dark foreground refinement) and T-550 (Settings page) — different files; source-side collisions zero. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` are expected at merge time and the rebaser picks the next free CL slot (T-560 reserved CL-54; T-570 and T-550 will pick CL-55 / CL-56 / CL-57).
- **Est:** 1h (two-line source revert + six snapshot re-records + spec/CL/tasks commit + manual sim verification + PR body assembly).
- **||:** P10-categories-brown (same cluster slot as T-430, which T-560 supersedes).

---

## Summary

- **Total tasks:** 73 (Phase 1–5) + 6 (Phase 6 consultant pass) + 5 (Phase 7 comments + ratings) + 6 (Phase 8 polish: T-310, T-320, T-321, T-322, T-323, T-330) + 5 (Phase 8 follow-ups surfaced by T-330: T-331, T-332, T-333, T-334, T-335) + 1 (Phase 9 categories modernization: T-340) + 17 (Phase 10: T-350, T-360, T-361, T-370, T-380, T-390, T-394, T-395, T-400, T-410, T-420, T-430, T-440, T-500, T-510, T-530, T-560) = 113
- **Total estimate:** ~143 hours + ~17 hours (Phase 6) + ~19 hours (Phase 7) + ~13 hours (Phase 8) + ~9 hours (Phase 8 follow-ups) + ~2 hours (Phase 9) + ~27 hours (Phase 10) = ~230 hours
- **Critical path:** Cluster A → Domain (T-010, T-011) → Networking (T-058) → Recipe Detail (T-110..T-121). Roughly 6 weeks at one focused contributor; 3–4 weeks with two contributors using the parallelism tags.
- **Parallel clusters once Cluster A lands:** B-domain, B-support, B-design, B-analytics can all run simultaneously.
- **Parallel clusters once Cluster C + D land:** E-feed, E-cats, E-search, E-detail, E-saved can all run simultaneously (Saved depends on Detail finishing the offline path).
- **Phase 6 parallelism:** F6-cards, F6-icon, F6-detail, F6-onb can all run in parallel. F6-cook (T-304, T-305) is the only sequential thread inside Phase 6.
- **Phase 8 parallelism:** P8-tab (T-310) and P8-darkmode (T-330) are fully independent. The widget cluster sequences T-320 → T-321 → T-322 → T-323 internally but is independent of P8-tab and P8-darkmode externally. So three worktrees can run simultaneously: one on T-310, one on T-320 (then handing forward inside the cluster), one on T-330.
- **Phase 9 parallelism:** P9-categories (T-340) is independent of every Phase 8 task and is the only Phase 9 work item.
- **Phase 10 parallelism:** P10-search (T-350 + T-500), P10-glyph (T-380), P10-latest-widget (T-360 → T-361), P10-lockscreen (T-370), P10-widget-appearance (T-390 → T-394 / T-395), P10-saved-desc (T-400), P10-detail-cleanup (T-410), P10-livetests (T-420), and P10-categories-brown (T-430) are independent of every Phase 8 + Phase 9 task and of each other. T-500 (Search-tab polish bundle) amends T-350's AC-20.3 carve-out and is bounded entirely to `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` + `SearchViewModel.swift` — independent of every other Phase 10 task source-wise. Parallel with T-510 (new-recipe surfacing, networking-only — different code path) and T-520 (color overhaul, `DODColor` token-level — different surface); if T-520 re-records any `SearchView` snapshot file T-500 also touches, T-500's semantic changes win because T-500 owns `SearchView.swift` for round 6. T-360 → T-361 sequences internally (T-361 consumes the `WidgetImageBridge` T-360 introduces). T-380 assumes T-310 already shipped. T-370 (lock-screen widget) ran on a parallel branch and conflicted with T-360 only on `Widget/DODAppWidgetBundle.swift` (each adds a registration line), resolved by the later PR rebasing on the first. T-390 is an audit-style task that touches `WidgetCard.Hero` (via a surgical `widgetAccentedRenderingMode(.fullColor)` opt-out) and adds new Tinted/Vibrant snapshot baselines — independent of T-360/T-361's image-bridge work (the audit doesn't depend on real-image render, only on the widget composition itself), and explicitly scoped to home-screen widgets so T-370's lock-screen widget code is not touched. T-400 is a single-string rewrite of `SavedRecipesWidget`'s gallery description — independent of every other Phase 10 entry (no shared files; touches only `Widget/SavedRecipesWidget.swift`'s description argument). T-410 (recipe detail cleanup) amends T-302's Phase 6 polish decision and assumes T-380 already shipped the bookmark glyph on the nav-bar Save — it touches `RecipeDetailView` + `RecipeDetailFloatingActions` + `CommentComposer` and is independent of every other Phase 10 task. T-420 (L2 nightly test for new-recipe surfacing) lives entirely inside `Packages/DODIntegrationTests/Tests/` — touches no source code, runs only in the nightly job per AC-T3, and shares no files with any other Phase 10 task. T-430 amends T-340's `CategoryListView` surface color and re-records the six `CategoryListViewSnapshotTests` baselines — bounded entirely to `Packages/DODFeatureCategories/**`, so it does not touch any widget surface, any other tab, or any DesignSystem token. T-394 (Featured widget contrast fix) and T-395 (Saved widget contrast audit verdict, clean) run on parallel branches against T-390's audit miss — both branches add their own copy of CL-46 + AC-23.7 and collide deliberately at merge time on `specs/dod-ios-app/{clarifications.md,spec.md,tasks.md,backlog.md}`; whoever lands second amends the existing CL-46 entry to fold both audits' framings. T-395 ships zero source edits (clean audit verdict) so the source-side merge is collision-free with T-394's `WidgetCard.swift` strengthening. New tasks added to Phase 10 should explicitly declare their parallelism tag and any cross-cluster dep.

Phase 5 starts when this list is approved and T-001 is picked up. Each PR cites the T-ID + the AC IDs it implements.
