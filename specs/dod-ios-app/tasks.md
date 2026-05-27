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

### T-391 — Widget gallery shows real recipe + hero image (Phase 10 fix)
- **Scope:** All three timeline providers (`FeaturedRecipeTimelineProvider`, `SavedRecipesTimelineProvider`, `LatestRecipeLockScreenTimelineProvider`) were short-circuiting `getSnapshot(in:completion:)` when `context.isPreview == true`, returning a hardcoded `.placeholder` entry that always has `heroImageFilename: nil` / `heroImageURL: nil`. That meant the **Add Widget gallery** — the moment the user is deciding whether to add the widget — always showed a fork-knife glyph on a brown gradient instead of the real recipe + image, even though the installed widget renders correctly post-add. Fix: prefer the live snapshot in the `isPreview` path, fall back to the hardcoded brand placeholder only when the App Group read returns empty (first launch before the feed has loaded, or — for the saved widget — the user genuinely has zero saved recipes). Reuses the existing `WidgetImageBridge` chain (T-360); no new wire format, no new App Group key, no new host write site.
- **Files:** `Widget/FeaturedRecipeTimelineProvider.swift` (one block in `getSnapshot`), `Widget/SavedRecipesTimelineProvider.swift` (same), `Widget/LatestRecipeLockScreenTimelineProvider.swift` (same — the lock-screen surface is text-only per CL-37 so the hero-image path isn't reached there regardless, but the title + excerpt should still be the user's real next-cook candidate rather than the canned "Garlic Butter Skillet Corn"), `specs/dod-ios-app/tasks.md` (this entry).
- **AC:** Pins AC-9.1..AC-9.4 (featured widget contract unchanged), AC-17.1..AC-17.9 (saved widget contract unchanged), AC-21.3 (hero image now appears in the gallery preview, not just post-add), AC-22.1..AC-22.5 (lock-screen contract unchanged). No spec amendment — this is a bug-fix that aligns observed behavior with what AC-21.3 ("widget shows the real hero image") already promised; the placeholder-only gallery render was an implementation regression, not a spec contract.
- **Deps:** T-360 (the `WidgetImageBridge` chain). T-361 not required — the saved widget will show real images once T-361 ships, and until then the gallery will show the post-T-321 placeholder behavior for the saved widget specifically (text-only saved entries, no hero) which is still strictly better than the canned three-recipe demo.
- **Est:** 0.5h (~3 files, ~10 lines each, no new types).
- **||:** P10-widget-appearance (sibling of T-390 — both polish the widget's first impression).

### T-392 — Featured-widget hero-image precache (Phase 10 fix)
- **Scope:** T-391 surfaced a second, deeper bug: the installed featured widget *also* never shows a hero image, not just the gallery preview. Root cause: `WidgetSnapshot.Entry.heroImageFilename` is populated from the URL on every feed publish (via `WidgetImageBridge.filename(for:)` — a pure derivation, no I/O), but **nothing actually writes the image bytes** to the bridge path. `RecipeStore.cacheImage(url:bytes:)` is the only call site that mirrors to `WidgetImageBridge.writeImage`, and the only caller of `cacheImage` was `SavedDependencies.cacheImage(_:forRecipeID:)` on explicit save. The feed loads its hero images via `AsyncImage` in `RecipeCard`, which is in-memory only — bytes never hit disk through any persistence path. Net effect: the widget's `AsyncImage(url: file://…)` against the bridge path returned `.empty` → `WidgetCard.Hero` rendered the gradient placeholder. Fix: in `LiveFeedDependencies.publishWidgetSnapshot(items:)`, after the wire-format write succeeds, dispatch a detached `Task` that fetches every snapshot entry's hero URL via an ephemeral `URLSession` (5s request / 10s resource timeout) and calls `store.cacheImage(url:bytes:)` for each. The existing `RecipeStore+ImageCache.cacheImage` site already mirrors to the bridge — no new write site needed; just a new caller. Best-effort by design: any per-entry failure is logged via `DODLog.app.notice` and skipped, and the widget falls back to the gradient placeholder for that entry (AC-21.3 contract preserved).
- **Files:** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedDependencies.swift` (new private `static precacheHeroImages(entries:into:)` method + a detached Task in `publishWidgetSnapshot`). `specs/dod-ios-app/tasks.md` (this entry).
- **AC:** Pins AC-9.1..AC-9.4, AC-21.2 (the host write hook now actually fires for featured-widget heroes, not just for saved ones), AC-21.3 (widget renders the real hero image post-add — the contract this task makes real), AC-21.4 (eviction parity — bytes go through the same `cacheImage` path as saved-recipe images, so `evictImagesIfNeeded` and the bridge-delete mirror still apply). No spec amendment — AC-21.2 always promised "every time `cacheImage` writes bytes, the bridge writes the file"; this task adds the missing call site that makes the promise true for the featured widget.
- **Deps:** T-360 (the `WidgetImageBridge` chain). Independent of T-361 — T-361 wires the saved widget to consume the bridge filenames already in its snapshot; this task ensures the FEED loads write featured-widget hero bytes onto disk. Sibling fix.
- **Est:** 0.5h (~30 lines + a fix to a `var → let` lint warning that surfaces from the new code).
- **||:** P10-widget-appearance (companion to T-391 — same widget-images-broken bug, two layers of fix).

### T-393 — Widget gallery placeholder uses live snapshot (T-391/T-392 follow-up)
- **Scope:** PR #46 shipped T-391/T-392 but visual verification on the iPhone 17 simulator showed the gallery preview was *still* rendering the hardcoded "Garlic Butter Skillet Corn" + brown gradient. Root cause: T-391 updated each provider's `getSnapshot(in:completion:)` to prefer the live snapshot when `context.isPreview == true`, but WidgetKit's Add-Widget gallery in iOS 17+ paints the preview thumbnail using **`placeholder(in:)`** — it does NOT necessarily call `getSnapshot` first. The three providers' `placeholder(in:)` methods still returned the hardcoded `*Entry.placeholder` constants, so the gallery thumbnail never saw the App-Group snapshot. Fix: move the same live-snapshot-or-fall-back-to-hardcoded logic from `getSnapshot` into `placeholder(in:)` in all three providers (the read is a UserDefaults plist load — single-digit ms, safely synchronous in a TimelineProvider). Bonus: `WidgetCard.Hero` previously used `AsyncImage(url:)` for the bridged file URL; `AsyncImage` is built on `URLSession` and does not reliably load `file://` URLs inside a widget extension process. Replaced the file-URL branch with `UIImage(contentsOfFile:)` + `Image(uiImage:)` — local read, single-digit ms, no async path, guaranteed to render the bridged bytes. Network URLs still take the `AsyncImage` branch so unit-test fixtures keep working. Visual verification: gallery now shows "Best Dutch Oven Recipes (30+ Tri..." with the actual recipe photo (Dutch oven of vegetables/meat), not the brown gradient.
- **Files:** `Widget/FeaturedRecipeTimelineProvider.swift` (rewrite `placeholder(in:)`, simplify `getSnapshot`), `Widget/SavedRecipesTimelineProvider.swift` (same shape), `Widget/LatestRecipeLockScreenTimelineProvider.swift` (same shape), `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` (add `loadLocalImage(at:)` helper, branch `Hero` on `url.isFileURL`), `specs/dod-ios-app/tasks.md` (this entry).
- **AC:** Pins AC-9.1..AC-9.4, AC-17.1..AC-17.9, AC-21.3 (gallery preview now shows the real hero image — the contract T-391 was supposed to deliver), AC-22.1..AC-22.5. No spec amendment — same surface as T-391, just a deeper layer of the same bug.
- **Deps:** T-391, T-392 (this is the follow-up that makes those two visually correct).
- **Est:** 0.5h (~4 files, ~15 lines each, no new types or wire-format changes).
- **||:** P10-widget-appearance (closes out the T-391/T-392 visual contract).

### T-580 — Search-tab tweaks: orange Clear All + per-term context-menu Clear (US-33)
- **Scope:** Round-7 backlog bundle of two Search-tab affordance polish items into one PR. **(1) Color match:** swap the `IdleSuggestionsView.recentsSection` Clear All button's `.foregroundStyle(DODColor.castIronBrown)` for `.foregroundStyle(DODColor.accent)` so it matches the Recipes-tab gear icon's tint (the gear icon inherits `.tint(DODColor.accent)` from `RootView.swift:127`/`RootView.swift:161` per US-32 / T-550). **(2) Per-term context menu:** wrap each recent-search `pill(...)` invocation in `IdleSuggestionsView.recentsSection` with a `.contextMenu` modifier containing one `Button(role: .destructive)` showing `Image(systemName: "trash")` + `Text("Clear")`. The button's action calls a new `SearchViewModel.removeRecentSearch(_:)` method that delegates to a new `RecentSearches.remove(_:)` method on the UserDefaults-backed store. The persistent store gains the case-insensitive removal API (mirroring `record(_:)`'s dedupe rule); the view-model gains the routing wrapper (mirroring `clearRecentSearches()`'s in-memory + persisted update pattern); the view gains the context-menu modifier on the existing pill closure. The bulk wipe-all behavior from US-29 / T-500 is unchanged — `clearRecentSearches()` stays in place and the Clear All button still calls it. CL-57 captures the brand-color match rationale + the per-term context-menu pattern, the considered alternatives (warmGold/burntOrange tokens, swipe-actions, list restructuring, confirmation dialog), and the coordination notes against T-590 (card long-press → Save) and T-610 (color refinement). 1 new L1 unit test in `RecentSearchesTests` locks the `RecentSearches.remove(_:)` case-insensitive-match + no-op-on-missing-term + only-target-term-removed contract.
- **Files:** `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (Clear All `foregroundStyle` token swap; `pill(...)` callsite gains `.contextMenu` modifier; `IdleSuggestionsView` gains `onRemoveRecent: (String) -> Void` closure parameter wired through `SearchView.swift`'s `IdleSuggestionsView(...)` initializer to `viewModel.removeRecentSearch(_:)`), `Packages/DODFeatureSearch/Sources/DODFeatureSearch/RecentSearches.swift` (new `public func remove(_ query: String)` mirroring `record(_:)`'s case-insensitive dedupe), `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchViewModel.swift` (new `public func removeRecentSearch(_ query: String)` calling `recents.remove(_:)` + re-reading `recents.recent()` into `recentSearches`), `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/RecentSearchesTests.swift` (new L1 unit test `removeOnlyMatchedTermLeavesOthersIntact`), `specs/dod-ios-app/spec.md` (US-33 + AC-33.1..AC-33.4), `specs/dod-ios-app/clarifications.md` (CL-57), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate the round-7 "Color refinements" + "Long-press context menus" bullets into "Recently graduated").
- **AC:** Implements AC-33.1, AC-33.2, AC-33.3, AC-33.4. Pins US-3 (text-query path unchanged), US-12 (recents persistence contract unchanged), US-29 (Clear All bulk wipe unchanged, no-results glyph unchanged, chip iconography unchanged), US-32 (gear-icon tint chain unchanged — Clear All now matches by adopting the same `accent` token).
- **Deps:** T-500 (the US-29 Search-tab polish bundle that established the Clear All button + the view-model-routes-recents-mutations pattern). T-550 (the US-32 gear icon whose `.tint(DODColor.accent)` propagation the Clear All retint matches). Independent of T-590 (card long-press → Save, different file) and T-610 (list-cell/search-bar color refinement, asset catalog).
- **Est:** 0.5h (~30 lines source + ~10 lines test + spec entries — XS+S bundle per backlog sizing).
- **||:** P10-search (companion to T-500, same file `SearchView.swift`, additive — no overlap with T-500's already-shipped semantics). Parallel with T-590 (P10-card-context, touches `FeedRow.swift` + `RecipeCard.swift`) and T-610 (P10-color-refinement-v3, touches DODDesignSystem asset catalog). Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` expected at merge time; T-580 reserves CL-57 and US-33; the next-to-land branch (T-590 or T-610) picks the next free CL slot.

### T-610 — Dark-mode SurfaceElevated round-7 refinement (US-30 amended, CL-59)
- **Scope:** Single asset-catalog hex swap in `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/SurfaceElevated.colorset/Contents.json` — the Dark Appearance entry moves from `#5A3520` (R `0x5A` / G `0x35` / B `0x20`, post-T-570) to `#553724` (R `0x55` / G `0x37` / B `0x24`, Spencer's round-7 user-eye verdict). Light Appearance stays `#FFFFFF` (already satisfies Spencer's round-7 light-mode request per T-520). CL-59 captures the rationale + the Option A vs Option B trade-off: Spencer's literal "list cells + search bars" framing technically reads as a per-surface scope (which would warrant a new dedicated `CellSurface` / `ChromeSurface` token applied only to `.listRowBackground(...)` + `.searchable` field surrounds — Option B), but the ~3 brightness points and ~2 hue points between `#5A3520` and `#553724` are at the sRGB JND (just-noticeable-difference) threshold on phone screens, so a single token refinement (Option A — what this PR ships) gives Spencer the requested color on list cells + search bars without forcing every consumer (chips, cards, sheets, snackbar, modals) to maintain a per-surface mapping. The design system stays at two surface tokens (`Surface` + `SurfaceElevated`), matching Apple's `systemBackground` + `secondarySystemBackground` pattern. WCAG AA contrast against the unchanged dark `Label` token (`#E6DECF` cream) only *improves* against the slightly-darker `#553724` (the L* lightness shift is small but in the favorable direction for cream-on-brown contrast).
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (AC-30.2 amended in place — the Dark Appearance hex moves to `#553724`, with the existing CL-55 amendment note extended to capture the CL-59 amendment line treatment), `specs/dod-ios-app/clarifications.md` (CL-59 appended after CL-55, before the Phase 11 amendments section), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the round-7 "list cells + search bars" color refinement entry to a one-line "Graduated to CL-59 / T-610" reference).
  - **Source (commit 2):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/SurfaceElevated.colorset/Contents.json` — three byte changes (R/G/B hex values in the Dark Appearance entry: `0x5A` → `0x55`, `0x35` → `0x37`, `0x20` → `0x24`).
  - **Out of bounds:** every snapshot baseline (intentionally deferred — see "Snapshot baseline deferral" below; this PR does not delete or re-record any `__Snapshots__/**/*.png`), the `Surface.colorset` (untouched), the `SurfaceElevated.colorset` Light Appearance entry (untouched — `#FFFFFF` already), every other `*.colorset` directory (byte-identical), `Colors.swift` (no new tokens, no rename), every Swift source file in the repo (no call-site edits — every reference to `DODColor.surfaceElevated` automatically picks up the new dark hex via the asset catalog), `bin/format.sh`, `swiftlint.yml`, `xcconfig` files, `project.yml`, the widget snapshot wire format, the deep-link grammar, analytics events. No new token, no rename, no call-site rewrite.
- **Snapshot baseline deferral (continues T-571's scope per CL-55):** the dark-mode `SurfaceElevated` retint drifts every `__Snapshots__/**/*.png` baseline rendered in dark mode (most of `DODDesignSystemTests`, the feature snapshot suites under `DODFeatureCategoriesTests` / `DODFeatureRecipeDetailTests` / `DODFeatureSearchTests`, and the widget appearance suites under `WidgetCardTintedAppearanceSnapshotTests` + `SavedWidgetSnapshotTests`). The existing tests use `record: .missing` so untouched PNGs stay byte-identical; T-610 intentionally does NOT delete and re-record any baseline here to keep the PR diff a single human-reviewable Contents.json edit. The re-record is filed as T-571 (Phase 10) per CL-55 — by the time T-571 runs, `main`'s SurfaceElevated dark hex is `#553724` and the regenerated PNGs reflect that value. AC-30.5's "every L4 snapshot baseline... is re-recorded" remains the long-term contract; T-571 is the scheduled satisfaction whether the drift came from T-570 (`#5A3520`) or T-610 (`#553724`).
- **AC:** Satisfies AC-30.2 as amended by CL-55 + CL-59 (Dark Appearance entry uses `#553724` rather than `#5A3520`). Pins AC-30.1 (Surface hex values unchanged), AC-30.3 (no edits outside the two surface colorsets), AC-30.4 (WCAG AA contrast preserved — actually improved by the slightly-darker `#553724`). Defers AC-30.5 (snapshot re-record) to T-571 with the documented `record: .missing` carry-over.
- **Deps:** T-570 (US-30 / CL-55) — depends on T-570's `SurfaceElevated.colorset` re-tint already being on `main` so the `#5A3520` hex is the value `#553724` is moving from. T-570 is merged. Parallel with T-580 (Search tab tweaks) and T-590 (card long-press → Save). Source-side collisions zero — T-580 touches `Packages/DODFeatureSearch/**`, T-590 touches `Packages/DODFeatureFeed/**` and/or `Packages/DODDesignSystem/Components/RecipeCard.swift` for the `.contextMenu` modifier; T-610 touches `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/SurfaceElevated.colorset/Contents.json`. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL slot (T-610 reserves CL-59; T-580 and T-590 will pick CL-60 / CL-61).
- **Est:** 20m (single hex swap + spec/CL/tasks/backlog commit + manual sim verification + PR body).
- **||:** P10-dark-foreground (independent of every other Phase 10 task source-wise; same cluster slot as T-570 / T-571, which this further refines).

### T-590 — Recipe card long-press → Save context menu (US-34, CL-60)
- **Scope:** Add a SwiftUI `.contextMenu` modifier to every `RecipeCard` call site (Feed, Search results, Saved list, Category recipes list). Menu contains a single `Button` with the `bookmark.fill` SF Symbol and the label "Save"; tapping it routes through a new `onSave: (RecipeListItem) -> Void` (Feed/Search/Categories) or `onSave: (Recipe) -> Void` (Saved) closure that each feature view exposes as an init parameter, with `nil` as default so existing call sites keep compiling. The closure is wired in `App/TabStack.swift` at the composition root: it caches the `RecipeListItem` via `RecipeStore.cache(listItem:)` (no-op if the row already exists — relevant for Categories/Search hits whose detail page hasn't been opened yet), calls `RecipeStore.toggleSaved(id:)` (the same save seam the detail-screen nav-bar bookmark uses, AC-4.7 / AC-5.1), then kicks the saved-recipes widget snapshot publisher (`SavedRecipesWidgetPublisher.publish()` — mirrors `LiveRecipeDetailDependencies.publishSavedWidgetSnapshot()`). A new `recipeCardContextMenu(onSave:)` View extension lives alongside `recipeCardTap` in `Components/RecipeCard.swift` so the menu glyph + label copy + SwiftUI shape are owned by the design system (the action closure is per-call-site per CL-60). Menu copy stays "Save" regardless of saved state per CL-60's always-"Save" decision — no per-row `isSaved` query in v1. Snapshot tests don't capture `.contextMenu` (the menu pops as a system overlay outside the snapshot host), so no new L4 baselines are added; existing card baselines stay byte-identical.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-34), `specs/dod-ios-app/clarifications.md` (CL-60), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate the "Recipe/Article card long-press → Save" item).
  - **Source (commit 2):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift` (add `recipeCardContextMenu(onSave:)` View extension alongside the existing `recipeCardTap`), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (new optional `onSave: (RecipeListItem) -> Void` init param; apply `.recipeCardContextMenu` at the FeedRow call site inside the LazyVGrid), `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (same — new optional init param + modifier application at the `.results` LazyVGrid card site), `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift` (new optional `onSave: (Recipe) -> Void` init param + modifier application — Saved tab passes a `Recipe`, not a `RecipeListItem`, so the closure signature differs at this surface), `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryRecipesView.swift` (same shape as FeedView/SearchView — `RecipeListItem` closure), `App/TabStack.swift` (build the `onSave` closure once per feature view, route through `dependencies.store.cache(listItem:)` + `dependencies.store.toggleSaved(id:)` + `SavedRecipesWidgetPublisher.publish()`).
  - **Tests (commit 2):** none added — context menus are SwiftUI system overlays that don't materialize into the snapshot host, and the save code path (`RecipeStore.toggleSaved(id:)`) is already L1-covered by `DODPersistenceTests` from the detail-screen save path. Existing card snapshot baselines stay byte-identical.
  - **Out of bounds:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift` `RecipeCard.init` (no signature change — the menu is applied via a View extension, not an init param, per CL-60); `RecipeDetailDependencies` (the detail-screen save flow is unchanged); `FeedDependencies` / `SearchDependencies` / `SavedDependencies` / `CategoriesDependencies` (no new protocol methods — the save closure is wired in `TabStack` against `dependencies.store` directly, sidestepping per-feature protocol churn); `RecipeListItem` / `Recipe` Domain types (no new `isSaved` field — per CL-60's no-Unsave-branch decision); any analytics event (no `recipeSavedFromCardContextMenu(...)` event added — the existing `recipeSaved` / `recipeUnsaved` events fire from `RecipeDetailViewModel.toggleSaved` on the detail path; refactoring telemetry-on-toggle out of the view model and into the store is out of scope for this story per CL-60); the `recipeCardTap` modifier (REG-DOD-LIST-SCROLL contract preserved — the new modifier composes alongside it without eating the tap gesture).
- **AC:** AC-34.1, AC-34.2, AC-34.3, AC-34.4, AC-34.5; pins AC-4.7 / AC-5.1 (detail-screen save flow unchanged), AC-17.3 / AC-17.6 (saved-recipes widget snapshot refresh fires on every save), REG-DOD-LIST-SCROLL (the tap-to-navigate gesture is not regressed by the additive context menu).
- **Deps:** — (independent; runs against current main). Coordination: T-580 (Search-tab tweaks) and T-610 (color refinement) are running on parallel branches in round 7. T-580 owns `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` source-side; if T-580 lands first T-590 rebases and re-applies its single-line `.recipeCardContextMenu` modifier inside the `.results` LazyVGrid. T-610 touches `DODColor` tokens / asset catalog only, no source collision with T-590. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot. (Rebase note: CL-59 was reserved by T-610 which landed first; T-590 renumbered to CL-60.)
- **Est:** 0.5h (~6 files, ~5 lines each, no new types, no protocol changes).
- **||:** P10-card-context-menu

### T-630 — Settings page expansion: five standard rows (US-36, CL-62)
- **Scope:** Round-7 backlog "Settings page expansion" item graduated. Extend `SettingsView.swift` + `SettingsViewModel.swift` (the US-32 / T-550 skeleton inside `Packages/DODFeatureFeed/`) with five new `Section`s after the existing metric-units toggle: (1) **Notifications** — `Toggle("Notify me when new recipes drop", ...)` bound to `dod.settings.notificationsEnabled` (default OFF, UI-only in v1 — APNs wire-up is T-631 follow-up); (2) **Appearance** — `Picker` between "Match System" / "Light" / "Dark" persisted under `dod.settings.appearance` as the raw value of an `AppearancePreference` enum (`"system"` / `"light"` / `"dark"`, default `"system"`); (3) **Default Share Format** — `Picker` between "Just the link" / "Link + recipe text" persisted under `dod.settings.shareFormat` as a `ShareFormatPreference` enum (`"linkOnly"` / `"linkAndText"`, default `"linkOnly"`); (4) **Clear Cached Recipe Images** — `Button` that calls a new `RecipeStore.clearImageCache()` method (purges unpinned `CachedImage` rows + the App Group file bridge mirrors, returns freed-byte total) and shows a `Snackbar` with the freed-MB count ("Freed X.X MB of cached images." or "Cache was already clear." for the 0-byte branch); (5) **Share Anonymous Usage Data** — `Toggle("Share anonymous usage data", ...)` bound to `dod.settings.telemetryEnabled` (default ON per constitution §9). The telemetry toggle's wire-up: `TelemetryDeckTransport.send(_:)` reads `UserDefaults.standard.object(forKey: "dod.settings.telemetryEnabled") as? Bool ?? true` at every send and short-circuits before invoking `TelemetryDeck.signal(...)` when the flag is false. The gate lives inside the production transport (not the `Telemetry` facade) so `RecordingTelemetryTransport` continues to capture every event for L1 test assertions — only the production wire path gates. The Appearance picker's selection is read by `RootView` at launch (via `UserDefaults.standard.string(forKey: "dod.settings.appearance")`) and applied via `.preferredColorScheme(...)` on the root `Group`: nil for `.system`, `.light` for `.light`, `.dark` for `.dark`. The Default Share Format flag is persisted in this PR; the share-payload composition that consumes the flag (extending the `ShareLink` in `RecipeDetailView` to optionally include the excerpt text) is intentionally deferred — a future task picks it up when product asks for it (the persistence contract lands here so the consumer can be a one-line edit later). CL-62 captures the per-row decisions, the test-fixture-isolation rationale for the transport-side gate, the considered alternatives (Notifications APNs-in-v1, Appearance default Light, three-option Share Format, confirmation alert on Clear Cache, pre-tap cache-size display, full-wipe Clear Cache, telemetry default OFF, facade-side gate vs constructor-injected gate), and the coordination notes against T-620 (Download button) and T-640 (Recipes & Articles rename). The cache-clear seam preserves pinned images (rows with non-nil `pinnedToSavedRecipeID`) so the AC-4.9 + AC-5.2 offline-saved-recipe contract is not violated.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-36 + AC-36.1..AC-36.8), `specs/dod-ios-app/clarifications.md` (CL-62 appended after CL-58), `specs/dod-ios-app/tasks.md` (this entry + T-631 follow-up), `specs/dod-ios-app/backlog.md` (graduate the round-7 "Settings page expansion / Add more standard settings" item).
  - **Source (commit 2):** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsView.swift` (add five new `Section`s, snackbar overlay for the cache-clear feedback, plumbing for the snackbar message state), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsViewModel.swift` (add the five UserDefaults-backed properties, the `AppearancePreference` + `ShareFormatPreference` enums, the `clearImageCache(via:)` async method that delegates to the store and formats the freed-MB snackbar message, a `snackbarMessage: String?` observed property the view consumes), `Packages/DODPersistence/Sources/DODPersistence/RecipeStore+ImageCache.swift` (add `public func clearImageCache() throws -> Int` — returns total bytes freed; iterates `CachedImage` rows where `pinnedToSavedRecipeID == nil`, sums `bytes.count`, deletes each row + calls `WidgetImageBridge.deleteImage(for:)` for each URL, calls `modelContext.save()`), `Packages/DODAnalytics/Sources/DODAnalytics/TelemetryDeckTransport.swift` (add a `telemetryEnabledKey` static constant `"dod.settings.telemetryEnabled"`, read the flag at the top of `send(_:)` and `return` before the SDK call when false; the default-ON behavior is `defaults.object(forKey:) as? Bool ?? true`), `App/RootView.swift` (one new `.preferredColorScheme(...)` modifier on the top-level `Group` that reads the persisted appearance preference at init time; the read uses a small `AppearancePreference.fromDefaults(UserDefaults.standard)` static helper exposed from `SettingsViewModel`).
  - **Tests (commit 2):** `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/SettingsViewModelTests.swift` (extend with five new test methods — `notificationsEnabledPersistsToInjectedDefaults`, `appearancePreferenceRoundTripsAllThreeCases`, `shareFormatPreferenceRoundTripsBothCases`, `telemetryEnabledDefaultsToTrueWhenAbsent` + `telemetryEnabledRespectsExplicitFalse`, `clearImageCacheFormatterRendersMBAndZeroCase`), `Packages/DODPersistence/Tests/DODPersistenceTests/RecipeStoreTests.swift` (extend `ImageCacheTests` with `clearImageCacheRemovesUnpinnedRowsAndReturnsFreedBytes` + `clearImageCachePreservesPinnedRows` + `clearImageCacheReturnsZeroWhenAlreadyEmpty`), `Packages/DODAnalytics/Tests/DODAnalyticsTests/TelemetryTests.swift` (extend with `telemetryDeckTransportShortCircuitsWhenDisabled` + `telemetryDeckTransportSendsWhenEnabledOrDefault` — these tests exercise `TelemetryDeckTransport` directly with an isolated UserDefaults suite, since the gate lives in the production transport not the facade), `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/SettingsViewSnapshotTests.swift` (re-record both baselines — the expanded view replaces the old three-row layout). Snapshot PNGs under `__Snapshots__/SettingsViewSnapshotTests/` re-recorded on the iOS simulator pass.
  - **Out of bounds:** the actual APNs wire-up (T-631 follow-up — `UNUserNotificationCenter.current().requestAuthorization`, `UIApplication.shared.registerForRemoteNotifications()`, push payload routing through `DeepLinkDispatcher`, backend opt-in mechanism); the share-payload composition that consumes `dod.settings.shareFormat` (a future task wires the flag into `RecipeDetailView`'s `ShareLink` to optionally include the excerpt text — the persistence contract lands here, the consumer lands later); any change to `AnalyticsEvent` enum (no new events — the gate operates on existing events); any change to constitution §9 (the privacy posture is preserved — gate is the constitution's existing toggle-off implementation per plan.md §10 R-3); any change to `Telemetry.shared` facade API (gate is internal to `TelemetryDeckTransport`); any change to `RecordingTelemetryTransport` (test fixture is unchanged — captures every event regardless of the gate); any change to `CachedImage` SwiftData schema or the existing `cacheImage` / `evictImagesIfNeeded` methods (`clearImageCache()` is additive, reuses the existing eviction-style fetch + delete + bridge-mirror cleanup); the US-32 metric-units toggle / About link / version footer (preserved as-is — three rows continue to render, five new rows are appended); the gear-icon NavigationLink target in `FeedView.swift` (unchanged — still pushes `SettingsView()`).
- **AC:** Implements AC-36.1, AC-36.2, AC-36.3, AC-36.4, AC-36.5, AC-36.6, AC-36.7, AC-36.8. Pins AC-32.1..AC-32.5 (US-32 unchanged), AC-6.2 (existing share flow unchanged when Share Format is at its default), AC-4.9 / AC-5.2 (offline / pinned-image contract preserved by exempting pinned rows from Clear Cache), NFR-2 (unpinned-eviction semantics mirrored by `clearImageCache`).
- **Deps:** T-550 (US-32 / the Settings skeleton this PR extends) — already on `main`. Independent of every other Phase 10 task source-wise. Coordination: T-620 (Download button) and T-640 (Recipes & Articles rename) running on parallel branches in this round 7 batch. T-620 owns `Packages/DODFeatureRecipeDetail/**` source-side; T-640 owns `App/AppTab.swift` + `FeedView.swift` nav title + a new article-renderer package; T-630 owns `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsView.swift` + `SettingsViewModel.swift`, `Packages/DODPersistence/Sources/DODPersistence/RecipeStore+ImageCache.swift`, `Packages/DODAnalytics/Sources/DODAnalytics/TelemetryDeckTransport.swift`, and `App/RootView.swift`. Source-side collisions zero. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot (T-630 reserves CL-62, US-36, T-630; T-620 / T-640 take subsequent slots).
- **Est:** 2h (five rows × ~5 lines of view code each, two new enums + four new view-model properties, one new `RecipeStore` method, one new `TelemetryDeckTransport` gate read, one `RootView` `.preferredColorScheme` modifier; ~7 new L1 tests across three packages; ~2 re-recorded L4 snapshot baselines).
- **||:** P10-settings-expansion (companion to T-550 — same `Packages/DODFeatureFeed/` territory, additive — no overlap with T-550's already-shipped semantics). Parallel with T-620 (different package, P10-download) and T-640 (different files, P10-recipes-articles-rename).

### T-631 — Notifications APNs wire-up (US-36 follow-up to T-630)
- **Scope:** Follow-up to T-630's Notifications row. T-630 ships the `dod.settings.notificationsEnabled` toggle + UserDefaults persistence with no APNs side-effect; this task is where the toggle actually does something. When the user flips the toggle ON, request notification authorization via `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])`. If granted, call `UIApplication.shared.registerForRemoteNotifications()`. If the user denies (or the system shows the auth prompt and the user dismisses without granting), reset the persisted flag to OFF and surface a snackbar explaining the system permission was declined ("Notifications were disabled in Settings — enable from iOS Settings → DOD."). When the user flips the toggle OFF after previously granting, deregister via `UIApplication.shared.unregisterForRemoteNotifications()`. Wire the device-token handoff to dutchovendaddy.com's backend (the WordPress plugin choice is a parallel decision — likely OneSignal or WPMobile.app's APNs bridge, captured in a fresh CL when T-631 graduates from this stub). Push payload routing: when a `dod://recipe/<id>` notification is tapped, route the URL through the existing `DeepLinkDispatcher` / `WidgetDeepLink` parser so the same deep-link contract widgets use also applies to push notifications (no new URL grammar). L1 tests for the auth-request flow stub against a `NotificationAuthorizing` protocol. L3 smoke test for "toggle ON → system permission prompt appears" (XCUITest can drive the SpringBoard alert via `addUIInterruptionMonitor` per Apple's docs).
- **Files:** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsViewModel.swift` (extend with the `requestNotificationAuthorization()` / `deregisterNotifications()` methods + injected `NotificationAuthorizing` protocol), `App/DODApp.swift` (handle the `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` + `application(_:didFailToRegisterForRemoteNotificationsWithError:)` callbacks via a SwiftUI `UIApplicationDelegateAdaptor`), `App/PushNotificationDelegate.swift` (new — `UNUserNotificationCenterDelegate` for foreground notifications), `App/RootView.swift` (`.onOpenURL` already routes deep-links; push tap goes through the same path via `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` → `UIApplication.shared.open(url:)`), plus a fresh CL capturing the WordPress backend plugin choice + device-token endpoint shape.
- **AC:** Pins AC-36.1 (the persistence contract T-630 established — flag still round-trips). Adds new ACs around auth-request flow, deny-handling, foreground delivery, and push-tap deep-link parity (captured in the spec amendment that lands with this task).
- **Deps:** T-630 (the toggle this task wires up).
- **Est:** 4h (auth request flow + delegate wire-up + backend choice CL + L1 + L3 tests; backend work is parallel — iOS side bounds to ~4h).
- **||:** P10-settings-expansion-followup (companion to T-630).

---

## Summary

- **Total tasks:** 73 (Phase 1–5) + 6 (Phase 6 consultant pass) + 5 (Phase 7 comments + ratings) + 6 (Phase 8 polish: T-310, T-320, T-321, T-322, T-323, T-330) + 5 (Phase 8 follow-ups surfaced by T-330: T-331, T-332, T-333, T-334, T-335) + 1 (Phase 9 categories modernization: T-340) + 14 (Phase 10: T-350, T-360, T-361, T-370, T-380, T-390, T-391, T-392, T-393, T-580, T-610, T-590, T-630, T-631) = 110
- **Total estimate:** ~143 hours + ~17 hours (Phase 6) + ~19 hours (Phase 7) + ~13 hours (Phase 8) + ~9 hours (Phase 8 follow-ups) + ~2 hours (Phase 9) + ~13 hours (Phase 10) = ~216 hours
- **Critical path:** Cluster A → Domain (T-010, T-011) → Networking (T-058) → Recipe Detail (T-110..T-121). Roughly 6 weeks at one focused contributor; 3–4 weeks with two contributors using the parallelism tags.
- **Parallel clusters once Cluster A lands:** B-domain, B-support, B-design, B-analytics can all run simultaneously.
- **Parallel clusters once Cluster C + D land:** E-feed, E-cats, E-search, E-detail, E-saved can all run simultaneously (Saved depends on Detail finishing the offline path).
- **Phase 6 parallelism:** F6-cards, F6-icon, F6-detail, F6-onb can all run in parallel. F6-cook (T-304, T-305) is the only sequential thread inside Phase 6.
- **Phase 8 parallelism:** P8-tab (T-310) and P8-darkmode (T-330) are fully independent. The widget cluster sequences T-320 → T-321 → T-322 → T-323 internally but is independent of P8-tab and P8-darkmode externally. So three worktrees can run simultaneously: one on T-310, one on T-320 (then handing forward inside the cluster), one on T-330.
- **Phase 9 parallelism:** P9-categories (T-340) is independent of every Phase 8 task and is the only Phase 9 work item.
- **Phase 10 parallelism:** P10-search (T-350 + T-500), P10-glyph (T-380), P10-latest-widget (T-360 → T-361), P10-lockscreen (T-370), P10-widget-appearance (T-390 → T-394 / T-395), P10-saved-desc (T-400), P10-detail-cleanup (T-410), P10-livetests (T-420), and P10-categories-brown (T-430) are independent of every Phase 8 + Phase 9 task and of each other. T-500 (Search-tab polish bundle) amends T-350's AC-20.3 carve-out and is bounded entirely to `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` + `SearchViewModel.swift` — independent of every other Phase 10 task source-wise. Parallel with T-510 (new-recipe surfacing, networking-only — different code path) and T-520 (color overhaul, `DODColor` token-level — different surface); if T-520 re-records any `SearchView` snapshot file T-500 also touches, T-500's semantic changes win because T-500 owns `SearchView.swift` for round 6. T-360 → T-361 sequences internally (T-361 consumes the `WidgetImageBridge` T-360 introduces). T-380 assumes T-310 already shipped. T-370 (lock-screen widget) ran on a parallel branch and conflicted with T-360 only on `Widget/DODAppWidgetBundle.swift` (each adds a registration line), resolved by the later PR rebasing on the first. T-390 is an audit-style task that touches `WidgetCard.Hero` (via a surgical `widgetAccentedRenderingMode(.fullColor)` opt-out) and adds new Tinted/Vibrant snapshot baselines — independent of T-360/T-361's image-bridge work (the audit doesn't depend on real-image render, only on the widget composition itself), and explicitly scoped to home-screen widgets so T-370's lock-screen widget code is not touched. T-400 is a single-string rewrite of `SavedRecipesWidget`'s gallery description — independent of every other Phase 10 entry (no shared files; touches only `Widget/SavedRecipesWidget.swift`'s description argument). T-410 (recipe detail cleanup) amends T-302's Phase 6 polish decision and assumes T-380 already shipped the bookmark glyph on the nav-bar Save — it touches `RecipeDetailView` + `RecipeDetailFloatingActions` + `CommentComposer` and is independent of every other Phase 10 task. T-420 (L2 nightly test for new-recipe surfacing) lives entirely inside `Packages/DODIntegrationTests/Tests/` — touches no source code, runs only in the nightly job per AC-T3, and shares no files with any other Phase 10 task. T-430 amends T-340's `CategoryListView` surface color and re-records the six `CategoryListViewSnapshotTests` baselines — bounded entirely to `Packages/DODFeatureCategories/**`, so it does not touch any widget surface, any other tab, or any DesignSystem token. T-394 (Featured widget contrast fix) and T-395 (Saved widget contrast audit verdict, clean) run on parallel branches against T-390's audit miss — both branches add their own copy of CL-46 + AC-23.7 and collide deliberately at merge time on `specs/dod-ios-app/{clarifications.md,spec.md,tasks.md,backlog.md}`; whoever lands second amends the existing CL-46 entry to fold both audits' framings. T-395 ships zero source edits (clean audit verdict) so the source-side merge is collision-free with T-394's `WidgetCard.swift` strengthening. New tasks added to Phase 10 should explicitly declare their parallelism tag and any cross-cluster dep.
- **Phase 11 parallelism:** P11-test-pyramid (T-600 through T-605) sequences internally — T-600 produces the audit doc that motivates T-601's spec amendment; T-601 locks the scheme name + four CI trigger surfaces; T-602 stands up the target + scheme; T-603 lands the five seed journeys against the target; T-604 wires the CI workflow that invokes the scheme; T-605 documents the label-gating policy for PR authors. The cluster is independent of every Phase 8 / 9 / 10 task. The branch (`feat/T-400-test-pyramid-l5-e2e`) carries all six commits and lands as a single merge commit (CONTRIBUTING.md "merge commit for multi-task clusters that need history preserved"). Follow-ups (T-610: host-side fake-dependencies switch; T-611: comments/ratings POST-path coverage against a stub; T-612: migrate de-facto-E2E methods out of `UITests/SmokeTests.swift`) are deliberately deferred — see `test-pyramid-audit.md` "Followups" section.

Phase 5 starts when this list is approved and T-001 is picked up. Each PR cites the T-ID + the AC IDs it implements.
