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

### T-620 — Explicit download-for-offline button on recipe detail (US-35, CL-61)
- **Scope:** Add a third nav-bar action on `RecipeDetailView` between the existing Save (AC-4.7, `bookmark` / `bookmark.fill`) and Share (AC-4.8, `square.and.arrow.up`) toolbar items. The new button renders `Image(systemName: "square.and.arrow.down")` and tap-routes through a new `RecipeDetailViewModel.downloadForOffline()` action that (a) marks the recipe row as offline-pinned via a new optional `downloadedAt: Date?` field on `CachedRecipe` (additive — qualifies as a lightweight migration per `Packages/DODPersistence/MIGRATION.md` R-5 since SwiftData allows adding optional fields without a migration plan stage), (b) downloads the hero image at full resolution via the existing `ImageLoader` → `RecipeStore.cacheImage(url:bytes:pinnedToSavedRecipeID:)` chain (reusing the existing pin-from-eviction mechanism per CL-61's "share the pin field" decision), and (c) surfaces a transient snackbar with copy "Recipe downloaded for offline use" (first-time download) or "Already downloaded" (re-tap or recipe is also-saved). The download is idempotent: re-tapping on a downloaded recipe is a no-op semantically (snackbar surfaces "Already downloaded", `downloadedAt` is not refreshed, no second image fetch); the button is not visually disabled per CL-61's discoverability rationale. The Save flag and the Download flag are independent — unsaving a recipe that was also explicitly downloaded keeps it pinned (the `downloadedAt` field survives the `toggleSaved` toggle); explicit Remove-download is deferred to a future story per CL-61's deferred-work section. New `RecipeDetailDependencies` methods: `downloadForOffline(recipe:) async throws` (the orchestration entry point, mirrors the shape of `toggleSaved(id:) async throws -> Bool`) and `isDownloaded(id:) async throws -> Bool` (the accessor the view model uses to decide between the two snackbar copy variants and to surface the "Downloaded for offline use" accessibility label). New `RecipeStore` methods: `markDownloaded(id:) throws` (sets `downloadedAt = .now` on the cached row + saves) and `isDownloaded(id:) throws -> Bool` (reads the flag). The `evictIfNeeded()` predicate is extended from `isSaved == false` to `isSaved == false && downloadedAt == nil` so downloaded recipes survive LRU eviction the same way saved ones do. The schema bump is additive on `CachedRecipe` (the existing V3 schema gains the optional field in place — V3 is currently still pre-production-migration so re-using it is the simplest path; if a future story needs to coexist with production V3 data, a `SchemaV4` lift is straightforward via the existing `MigrationPlan` lightweight pattern). No new analytics event (per CL-61's tight allowlist decision); no new design tokens; no new deep-link cases.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-35, AC-35.1..AC-35.6), `specs/dod-ios-app/clarifications.md` (CL-61), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the "Download for offline viewing button" item to a one-line "Graduated to US-35 / CL-61 / T-620" reference).
  - **Source (commit 2):** `Packages/DODPersistence/Sources/DODPersistence/CachedRecipe.swift` (add `downloadedAt: Date?` optional field with `nil` default on init), `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (add `markDownloaded(id:) throws` + `isDownloaded(id:) throws -> Bool` methods; extend `evictIfNeeded` predicate to OR-check the new flag — `isSaved == false && downloadedAt == nil`), `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailDependencies.swift` (add `downloadForOffline(recipe:) async throws` + `isDownloaded(id:) async throws -> Bool` to the protocol with default no-op implementations so existing fakes keep compiling, wire the live implementation against `RecipeStore.markDownloaded(id:)` + `ImageLoader.data(for:)` + `RecipeStore.cacheImage(url:bytes:pinnedToSavedRecipeID:)`), `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailViewModel.swift` (add `isDownloaded: Bool` observable property, hydrate from `dependencies.isDownloaded(id:)` in `onAppear()`, add `downloadForOffline() async` that calls the dependency + surfaces the snackbar copy + flips `isDownloaded` to true), `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` (add a third `Button` between Save and Share in `toolbarItems` rendering `Image(systemName: "square.and.arrow.down")` with accessibility-label branching on `viewModel.isDownloaded`), `App/AppDependencies.swift` (wire the live `imageLoader` singleton into `LiveRecipeDetailDependencies` so the new download orchestration has the network fetcher it needs — adds one `imageLoader` parameter to the `LiveRecipeDetailDependencies.init(...)` call site).
  - **Tests (commit 2):** new test `downloadForOfflineMarksRecipeAndShowsSnackbar()` in `RecipeDetailViewModelTests.swift` that proves the L1 contract: starting from a recipe loaded into the view model, calling `viewModel.downloadForOffline()` invokes `dependencies.downloadForOffline(recipe:)`, flips `viewModel.isDownloaded` to true, and sets `viewModel.snackbarMessage` to "Recipe downloaded for offline use" on the first-time path. Extends `FakeRecipeDetailDependencies` with a `downloadedRecipeIDs: Set<Int>` spy and `downloadForOffline(recipe:)` / `isDownloaded(id:)` implementations matching the protocol shape. Adds a second test `downloadForOfflineSurfacesAlreadyDownloadedSnackbarWhenSaved()` that hydrates a saved recipe (`savedIDs.contains(...)`), calls download, and asserts the "Already downloaded" snackbar copy fires per AC-35.3. The persistence-layer contracts (the new `downloadedAt` field, `markDownloaded(id:)` round-trip, and the extended eviction predicate) are covered by the new test `downloadedRecipeSurvivesLRUEviction()` in `RecipeStoreTests.swift` that proves a recipe with `downloadedAt != nil` and `isSaved == false` is NOT evicted when the LRU cap is exceeded — pins AC-35.5's "independent flags both pin from eviction" contract.
  - **Out of bounds:** `Packages/DODPersistence/Sources/DODPersistence/SchemaV3.swift` (no model-list change — `CachedRecipe` is already in V3's models list; adding an optional field doesn't require a new schema version per MIGRATION.md R-5 lightweight rule); `Packages/DODPersistence/Sources/DODPersistence/CachedImage.swift` (no rename of `pinnedToSavedRecipeID` — CL-61's decision to reuse the field's semantic across Save and Download paths means the name stays historical-but-overloaded); `Packages/DODDomain/Sources/DODDomain/Recipe.swift` (no `downloadedAt` field on the Domain `Recipe` — it's local state only, exposed via `RecipeStore.isDownloaded(id:)` not Domain shape); the Save flow (AC-4.7 / AC-5.1 unchanged); the Share flow (AC-4.8 unchanged); the saved-recipes widget publisher (`SavedRecipesWidgetPublisher` — the widget surfaces `isSaved` recipes, not explicitly-downloaded ones); any analytics event (per CL-61); the snackbar mechanism (reuses existing `RecipeDetailView.snackbar` overlay); the haptic feedback (the existing `.sensoryFeedback(.success, trigger: viewModel.isSaved)` is bound to the Save flag; Download does NOT trigger a haptic per CL-61's out-of-scope-for-v1 decision); `RecipeListItem` (no `downloadedAt` field — same Domain-state-only rationale as `Recipe`); `RecipeDetailViewModel.toggleSaved` (unchanged — Save and Download are independent paths); `evictImagesIfNeeded` (image-side eviction is unchanged because the existing `pinnedToSavedRecipeID` field already covers the Download path per CL-61's shared-pin-field decision).
- **AC:** AC-35.1, AC-35.2, AC-35.3, AC-35.4, AC-35.5, AC-35.6; pins AC-4.7 / AC-5.1 (Save flow unchanged), AC-4.8 (Share flow unchanged), AC-5.2 (saved-recipe auto-download still fires on save and is the contract the "Already downloaded" snackbar copy keys off when `isSaved == true`), NFR-1 (the LRU cap is unchanged — downloaded recipes pin from eviction alongside saved ones per AC-35.5).
- **Deps:** — (independent; runs against current main). Coordination: T-630 (Settings expansion) and T-640 (Recipes & Articles rename) running on parallel branches in round 7. T-630 touches `Packages/DODFeatureSettings/**`, T-640 touches `Packages/DODFeatureFeed/**` + `App/` — T-620 touches `Packages/DODFeatureRecipeDetail/**` + `Packages/DODPersistence/**`. Source-side collisions: zero. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot.
- **Est:** 0.5h (~6 files, additive schema field + protocol additions + one new view button + view-model wiring + L1 test).
- **||:** P10-detail-download

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

### T-631 — Local notifications + type-aware copy + gated test affordance (US-42, CL-100; follow-up to T-630)
- **Scope:** Follow-up to T-630's Notifications row, re-scoped from the original APNs sketch to **on-device *local* notifications** for v1 (CL-100 decision 1 — there is no v1 backend publish signal, so this lands the full device-side plumbing a future push task reuses verbatim; **no APNs registration, no device-token handoff, no backend** in this task). T-630 shipped the `dod.settings.notificationsEnabled` toggle + UserDefaults persistence with no side-effect; this task makes the toggle do something. **(1) Authorization (AC-42.1):** flipping the toggle ON calls a new `NotificationService.requestAuthorization()` wrapping `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`; on grant the flag persists `true`, on deny the toggle reverts to OFF and the flag is set `false`. **(2) Type-aware content builder (AC-42.2):** a pure function keyed on `PostKind` (US-37) — `.recipe` → title "New Recipe 🍳" / body "\<title\> just dropped — tap to start cooking.", `.article` → title "New Article 📖" / body "\<title\> is up — tap to read." — lives in `DODFeatureFeed` so the package test target covers it. **(3) Scheduling + suppression gate (AC-42.4):** `NotificationService.scheduleNewPostNotification(title:postKind:recipeID:)` builds a `UNMutableNotificationContent` + `UNTimeIntervalNotificationTrigger` (~1–2s), stamps the deep-link URL into `userInfo` under `"dod.deeplink"` (`dod://recipe/<id>` or `dod://article/<id>`), and **short-circuits — scheduling nothing — when `dod.settings.notificationsEnabled` is OFF or permission is not granted** (the single gate; the test button goes through this same method so toggle-off suppresses it too). **(4) Tap routing (AC-42.3):** a `UNUserNotificationCenterDelegate` (set on `DODApp`/`AppDelegate`) reads `userInfo["dod.deeplink"]` in `userNotificationCenter(_:didReceive:)` and routes the URL through the existing `WidgetDeepLinkParser` / `DeepLinkDispatcher` / `RootView.handle(...)` path (no new URL grammar — REG-10). **(5) Foreground banner (AC-42.5):** `willPresent` returns `[.banner, .sound, .list]` so foreground notifications surface. **(6) Temporary DEBUG test affordance (AC-42.6):** a `#if DEBUG` "▸ Test: Simulate New Post" button directly below the notifications toggle in `SettingsView`, gated by the toggle, fires two sample notifications ~2s apart — an article ("Best Dutch Oven Recipes (30+ Tried and Tested Favorites)", `.article`) and a recipe ("Cast Iron Burgers (Easy Skillet Recipe)", `.recipe`) — to exercise the path in the simulator (v1 has no server trigger). L1 tests: the content-builder copy for each `PostKind`, the toggle-off suppression (stub scheduler records zero requests when the flag is off), and the `userInfo` deep-link payload shape per kind. **No new `AnalyticsEvent`** (CL-100 decision 7 — local notifications are device-local; constitution §9 gains a clarifying note only).
- **Files:**
  - **Spec/clarifications/tasks (commit 1):** `specs/dod-ios-app/spec.md` (US-42 + AC-42.1..AC-42.6; AC-36.1 amended in place to note T-631 wired it locally), `specs/dod-ios-app/clarifications.md` (CL-100 appended), `specs/dod-ios-app/tasks.md` (this entry), `specs/dod-ios-app/backlog.md` (graduate the round-8 "Notifications" item), `specs/constitution.md` (§9 device-local-notifications clarifying note).
  - **Source (commit 2):** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/NotificationContent.swift` (new — the pure `PostKind`→title/body/deep-link content builder + the notifications-enabled read; unit-tested), `App/NotificationService.swift` (new — the `UNUserNotificationCenter` authorization + scheduling wrapper with the suppression gate), `App/NotificationCoordinator.swift` (new — the `UNUserNotificationCenterDelegate` for `didReceive` tap-routing + `willPresent` foreground banner, wired into the deep-link dispatcher), `App/DODApp.swift` (set the notification-center delegate at launch via an `AppDelegate` / `UIApplicationDelegateAdaptor`), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsView.swift` + `SettingsViewModel.swift` (toggle ON → authorization request via an injected closure seam; the `#if DEBUG` test button), `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/NotificationContentTests.swift` (new — L1 copy + suppression + payload-shape tests).
- **AC:** Pins AC-36.1 (the persistence contract still round-trips). Implements US-42 AC-42.1..AC-42.6.
- **Deps:** T-630 (the toggle this wires up), T-640 (`PostKind`).
- **Est:** 3h (local-notification service + delegate + content builder + toggle wiring + DEBUG test button + L1 tests; no backend).
- **||:** P10-settings-expansion-followup (companion to T-630). Touches the composition root + deep-link routing → PR carries the `e2e` label.

### T-632 — Notification deep-links fetch uncached posts + real test IDs (US-42, REG-20, CL-101; fix follow-up to T-631)
- **Scope:** Fix the confirmed T-631 bug where notification deep-links resolved **cache-only** and so opened nothing for newly-published (never-cached) posts — the feature's only real use case (CL-101). **(1) Fetch-on-cache-miss in `RootView.resolveRecipeRoute(id:autoStartCookMode:)` (additive):** when `store.recipeWithoutTouching(id:)` misses, fetch the post by id via a new `WPRestClient.post(id:)` (`GET /wp/v2/posts/<id>?_embed=wp:featuredmedia` → `RecipeListItem` carrying `canonicalURL`), then route to `.recipe(item:)`; the recipe-detail screen runs the existing JSON-LD-parse / article-classify fetch (AC-4.11 / AC-37.2). The cache-hit path is unchanged (widgets/Spotlight stay network-free + don't bump the recently-viewed LRU per REG-10); a genuinely-unresolvable id still degrades to `nil` ("ignore") with a distinct `deep link: recipe <id> fetch failed` log. **(2) Article routing via the detail screen (not a new route case):** articles (PostKind `.article`, US-37 / CL-63) resolve through the same `.recipe(item:)` route — `RecipeDetailViewModel.fetchAndParse()` classifies and transitions to `.article`, which `RecipeDetailView` renders via `ArticleDetailView`, so tapping an article notification opens the article detail. The resolution policy lives in a new standalone `RecipeRouteResolver` (two injected I/O edges: cache lookup + remote fetch) so it is unit-testable without a SwiftUI host. **(3) Real test ids (CL-101 decision 3):** the DEBUG "Simulate New Post" affordance now fires real WP ids so the live fetch path has a target — article `23406` ("Best Dutch Oven Recipes (30+ Tried and Tested Favorites)") and recipe `21238` ("Garlic Butter Skillet Corn (Easy 15-Minute Side Dish)"); the fictional "Cast Iron Burgers" (which doesn't exist on the blog) is swapped out and its title updated. L1 tests: `RecipeRouteResolver` (cached → no fetch; uncached → fetch + route; uncached-article → `.recipe` route carrying the article's post; fetch-failure → `nil`) + `WPRestClient.post(id:)` round-trip. **No new `AnalyticsEvent`.**
- **Files:**
  - **Spec/clarifications/tasks (commit 1):** `specs/dod-ios-app/spec.md` (REG-20 in the Test pyramid), `specs/dod-ios-app/clarifications.md` (CL-101 appended), `specs/dod-ios-app/tasks.md` (this entry).
  - **Source + tests (commit 2):** `Packages/DODNetworking/Sources/DODNetworking/WPRestClient+Posts.swift` (new `post(id:)` single-post fetch), `App/RecipeRouteResolver.swift` (new — the testable fetch-on-miss resolution policy + article-routing doc), `App/RootView.swift` (`resolveRecipeRoute` delegates to the resolver), `App/AppDependencies.swift` (new `fetchListItem(forPostID:)` exposing the REST client to the resolver), `App/NotificationService.swift` (real test ids + corrected recipe title), `AppTests/RecipeRouteResolverTests.swift` (new — L1 resolver cases), `Packages/DODNetworking/Tests/DODNetworkingTests/WPRestClientTests.swift` (additive `fetchesSinglePostByID` case).
- **AC:** Implements US-42 AC-42.6 (the DEBUG affordance now opens real posts). Locks REG-20. Pins AC-4.11 + AC-37.2 (recipe-vs-article classification on the detail screen), REG-10 (cache-hit + LRU untouched).
- **Deps:** T-631 (the notification + deep-link plumbing this fixes), T-640 (`PostKind` + the article-detail classification path), T-110..T-121 (the recipe-detail fetch path the route lands on).
- **Est:** 2h (single-post fetch endpoint + resolver extraction + fetch-on-miss wiring + real test ids + L1 tests).
- **||:** P10-settings-expansion-followup (fix follow-up to T-631). Touches the composition root + deep-link routing → PR carries the `e2e` label.

### T-633 — Remove DEBUG test affordance + em-dash-free notification copy (US-42, CL-102; follow-up to T-631/T-632)
- **Scope:** Two small follow-ups to the notifications work (CL-102). **(1) Remove the temporary DEBUG "Simulate New Post" test scaffold** now that the end-to-end path (schedule → fire → banner → tap → fetch → detail) is verified in the simulator via the T-632 real-id swap: delete the `#if DEBUG` "▸ Test: Simulate New Post" button in `SettingsView`, the `onSimulateNewPosts` closure plumbing threaded through `FeedView` → `TabStack`, and `NotificationService.simulateNewPosts()` (the `#if DEBUG` method firing the two sample notifications). The real `scheduleNewPostNotification(title:postKind:recipeID:)` API is **unchanged** and stays the seam the deferred push follow-up reuses; AC-42.4's single suppression gate is untouched. **(2) Em-dash-free notification copy:** the AC-42.2 bodies in `NotificationContentBuilder` swap " — " (em dash) for a period — recipe body "\<postTitle\> just dropped. Tap to start cooking." and article body "\<postTitle\> is up. Tap to read." Titles unchanged; no em/en dashes anywhere in the notification copy. L1: update the `NotificationContentTests` body assertions to the new strings. **No new `AnalyticsEvent`.**
- **Files:**
  - **Spec/clarifications/tasks (commit 1):** `specs/dod-ios-app/spec.md` (AC-42.6 struck through with "removed in T-633" note; AC-42.2 copy amended in place; AC-42.4 gate note trimmed; "Temporary test affordance" note struck through), `specs/dod-ios-app/clarifications.md` (CL-102 appended), `specs/dod-ios-app/tasks.md` (this entry).
  - **Source + tests (commit 2):** `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsView.swift` (delete the DEBUG button + `onSimulateNewPosts` property/init param), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (delete the `onSimulateNewPosts` property/init param + the pass-through into `SettingsView`), `App/TabStack.swift` (delete the `onSimulateNewPosts:` argument), `App/NotificationService.swift` (delete the `#if DEBUG simulateNewPosts()` method + trim its stale comment), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/NotificationContent.swift` (em-dash-free recipe + article bodies), `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/NotificationContentTests.swift` (update the two body assertions).
- **AC:** Amends US-42 AC-42.2 (copy) + AC-42.6 (affordance removed). Pins nothing new; the existing `NotificationContentBuilder` L1 copy tests are updated to the new strings.
- **Deps:** T-631 (the notification plumbing + test affordance this removes), T-632 (the real-id swap whose simulator verification makes the scaffold removable).
- **Est:** 20m (deletion + copy change + test-string updates).
- **||:** P10-settings-expansion-followup. Deletion + copy only — does not touch the composition root's deep-link routing meaningfully → **no `e2e` label**.

### T-640 — Recipes & Articles tab + article rendering for non-JSON-LD posts (US-37, CL-63)
- **Scope:** Round-7 backlog bundle of two coupled changes into one PR: **(1) Tab rename:** `AppTab.swift` `case .feed` `title` from "Recipes" to "Recipes & Articles" (the bottom-tab label updates automatically via SwiftUI's `Label(systemImage:)`); `FeedView.swift` `.navigationTitle("Recipes")` → `.navigationTitle("Recipes & Articles")`. **(2) Article rendering path:** add a new `PostKind` enum to `DODDomain` (`.recipe` / `.article`) surfaced on the existing `Recipe` domain type via a `kind: PostKind` property; add a new `ArticleBodyExtractor` enum to `DODSupport` that walks the rendered HTML page (the same string `RecipePageFetcher.html(for:)` already fetches) and pulls the article body text via `HTMLSanitizer.plainText(from:)`; modify `RecipeDetailViewModel.fetchAndParse()` so when `parseJSONLD(...)` throws, it calls `ArticleBodyExtractor.extract(html:)` — on non-empty result, classify as `.article`, persist via `mergeDetail(_:)` (with `articleBodyHTML` populated), call `markJSONLDFailed(id:)` (the field is now the kind discriminator, not the hide signal), transition `LoadState` to a new `.article(Recipe)` case; on empty result, fall through to the existing `.unavailable` path. Add a new `ArticleDetailView` in `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/` that renders hero + title + published date + sanitized HTML body + Share button (preserved per AC-4.8) + Save button (preserved per AC-4.7, with `articleBodyHTML` persisted on save per AC-37.6). `RecipeDetailView.body`'s `content` switch gains a `case .article(let recipe):` arm rendering `ArticleDetailView(recipe: recipe)`. `CachedRecipe` (and `Recipe` Codable) gain a new optional `articleBodyHTML: String?` field via a fresh `SchemaV4` lightweight migration (additive optional, no rename, no required-field promotion). `RecipeStore.listItems(forIDs:)` and `RecipeStore.recentlyViewed(limit:)` drop the `jsonLDFailedAt == nil` predicate clause so articles are no longer hidden from list queries (AC-37.4). The pull-to-refresh `clearBlocklist()` call site is preserved so server-side JSON-LD fixes can re-classify back to recipe rendering on the next detail open. CL-63 captures the rationale, the lineage to CL-9 + CL-10, the `PostKind`-on-Recipe vs separate-`Article` decision, the article-body extractor's WordPress `entry-content` / `<article>` / `<main>` fallback chain, the deliberate UI exclusions (no Cook Mode, no servings stepper, no ratings, no comments composer, no related strip), the `jsonLDFailedAt` field-semantic reframe, and the coordination notes against T-620 + T-630 + T-650.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-37 + AC-37.1..AC-37.8; AC-1.7 + AC-4.11 amended in place with strike-through), `specs/dod-ios-app/clarifications.md` (CL-63 appended; CL-9 + CL-10 amended in place with strike-through), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the round-7 "Recipes tab rename + content typing" item to "Recently graduated").
  - **Source (commit 2):**
    - `Packages/DODDomain/Sources/DODDomain/PostKind.swift` (new — the `PostKind` enum).
    - `Packages/DODDomain/Sources/DODDomain/Recipe.swift` (add `kind: PostKind` property + `articleBodyHTML: String?` property; update `init`; default to `.recipe` for back-compat).
    - `Packages/DODSupport/Sources/DODSupport/ArticleBodyExtractor.swift` (new — the HTML body extractor with `entry-content` / `<article>` / `<main>` / body fallback chain).
    - `Packages/DODPersistence/Sources/DODPersistence/CachedRecipe.swift` (add `articleBodyHTML: String?` field).
    - `Packages/DODPersistence/Sources/DODPersistence/SchemaV4.swift` (new — lightweight migration that adds the `articleBodyHTML` column).
    - `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (toDomain + mergeDetail propagate `articleBodyHTML` + `kind`; `listItems(forIDs:)` + `recentlyViewed(limit:)` drop the `jsonLDFailedAt == nil` predicate).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailViewModel.swift` (`LoadState.article(Recipe)` case; `fetchAndParse()` branches to article extraction on JSON-LD failure).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailDependencies.swift` (add `extractArticleBody(html:) -> String` to the protocol surface; live wiring calls `ArticleBodyExtractor.extract(html:)`).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/ArticleDetailView.swift` (new — the article-rendering screen).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` (`case .article(let recipe):` arm in the `content` switch; `handleLoadStateChange` skips the auto-pop for the article case).
    - `App/AppTab.swift` (change `case .feed` `title` to "Recipes & Articles").
    - `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (change `.navigationTitle("Recipes")` to `.navigationTitle("Recipes & Articles")`).
  - **Tests (commit 2):**
    - `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/RecipeDetailViewModelTests.swift` (new L1 tests `jsonLDFailureWithArticleBodyClassifiesAsArticle`, `jsonLDFailureWithEmptyBodyFallsThroughToUnavailable`, `successfulJSONLDClassifiesAsRecipe`; update existing `fetchFailureMarksBlocklistAndTransitionsToUnavailable` to reflect the new article-fallback semantics).
    - `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/FakeRecipeDetailDependencies.swift` (add `var articleBodyToExtract: String = ""` test surface; implement the new `extractArticleBody(html:)` method).
    - `Packages/DODSupport/Tests/DODSupportTests/ArticleBodyExtractorTests.swift` (new — L1 tests for the extractor: `entry-content` happy path, `<article>` fallback, `<main>` fallback, body-only fallback, empty-on-missing).
    - `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/ArticleDetailViewSnapshotTests.swift` (new — L4 baselines for `ArticleDetailView` in light + dark on iPhone 13 baseline at default Dynamic Type).
    - Re-record T-310 / T-334 tab-bar baselines + any existing FeedView screen-level baselines that capture the nav title (intentional visual change).
  - **Out of bounds:** the `RecipeRoute.recipe(item:)` grammar (no new route case — `ArticleDetailView` is reached via the same route, just a different `LoadState` branch in `RecipeDetailView`); the deep-link grammar (`dod://recipe/<id>` works for both kinds); the widget surfaces (`WidgetSnapshot` / `SavedRecipesWidgetSnapshot` are kind-agnostic); the analytics events (no `articleViewed` event — `recipeView(recipeID:)` fires regardless of kind); `RecipePageFetcher` (same HTML fetch); `JSONLDRecipeParser` (same throw on failure; the article branch is layered atop); the search index (`CachedIngredient` — articles have no ingredients to index); any non-`feed` `AppTab` case; any non-rename surface on `FeedView` (the only delta is the nav-title string); the constitution (no §-level change — no new dep, no new analytics event, no new data category); the Cook Mode gate (already correctly handles empty `recipe.instructions`); the `recipeYield` parsing (articles have no servings).
- **AC:** Implements AC-37.1, AC-37.2, AC-37.3, AC-37.4, AC-37.5, AC-37.6, AC-37.7, AC-37.8. Amends AC-1.7 (strike-through original "filtered out" wording; new article-routing path) and AC-4.11 (note that article posts use HTML rendering, not auto-pop). Pins AC-1.3 (list row format unchanged for articles), AC-4.7 / AC-4.8 (Save + Share preserved on `ArticleDetailView`), AC-5.1 (save toggle path is the same `RecipeStore.toggleSaved(id:)` seam), AC-5.3 (Saved tab shows saved articles alongside saved recipes in the same row format), AC-5.4 (offline read works for saved articles), AC-16.1 (tab ordering unchanged), AC-16.4 (telemetry name unchanged), CC-1 / CC-2 / CC-7 / CC-8 (accessibility, offline banner, performance, iPad layouts) for `ArticleDetailView`. Implements the CL-63 amendments to CL-9 + CL-10.
- **Deps:** — (independent of every other Phase 10 / Phase 11 task source-wise). Parallel with T-620 (Download for offline button, touches `RecipeDetailView` for a new nav-bar action) and T-630 (Settings expansion, touches `SettingsView`). No source-side collisions expected — T-620's nav-bar action sits alongside the existing Save + Share (which T-640 preserves), and T-630 touches a different feature view entirely. T-650 (Gallery/List view toggle) is **queued for after T-640 merges** because T-650 also touches `FeedView` heavily; sequencing avoids a heavy-merge conflict.
- **Est:** 3h (new domain enum + extractor + article view + view-model branch + schema migration + L1 tests + L4 baselines + spec entries — M per backlog sizing; the article-body extractor is the hardest piece, the rest is plumbing).
- **||:** P10-articles (independent of every other Phase 10 task). Source-side collisions zero with T-620 / T-630. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot (T-640 reserves CL-63, US-37, T-640).

### T-650 — Gallery ↔ List view toggle on Recipes & Articles + Search (US-38, CL-64)
- **Scope:** Round-7 backlog "Layout toggle" item graduated. Add a nav-bar toggle button on both `FeedView` (Recipes & Articles tab) and `SearchView` (Search tab) that flips a shared `@AppStorage("dod.recipeListLayout")`-backed preference between two layouts: **gallery** (the existing 2-column `LazyVGrid` per CC-9 — the default and pre-T-650 behavior) and **list** (a new denser single-column variant). Introduce a new `RecipeListLayout` enum in `DODDesignSystem` with `.gallery` / `.list` cases, the `@AppStorage` key constant, the per-case toggle icon name (`square.grid.2x2` for `.gallery`, `list.bullet` for `.list` — current-state convention per CL-64, NOT destination convention), and the per-case accessibility label + hint strings. Introduce a new `RecipeCard.ListRow` view in `DODDesignSystem` sibling to the existing `RecipeCard` — `HStack` with a 60pt thumbnail on the leading edge, title + 1-line excerpt in the middle, optional time chip on the trailing edge, on a `DODColor.surfaceElevated` background inside a `RoundedRectangle(cornerRadius: DODSpacing.sm)`. On `FeedView`, add a second `ToolbarItem` in the existing `.topBarTrailing` block, ordered before the gear icon so the gear stays at the absolute trailing edge per AC-32.1. On `SearchView`, add the first `ToolbarItem` in a new `.toolbar { }` block with `.topBarTrailing` placement (with the `#if os(iOS)` / `.automatic` fallback for the macOS test slice). Both views' `content` switch on the read-back `@AppStorage` value: `.gallery` keeps the existing `LazyVGrid` rendering byte-identical; `.list` renders a `LazyVStack` of `RecipeCard.ListRow` items composed with the same `recipeCardTap` + `recipeCardContextMenu` modifiers the gallery cells use. CL-64 captures the icon-convention deviation rationale (current-state per Spencer's explicit ask, NOT destination), considered alternatives (destination convention, segmented control, Settings-page row, per-tab persistence, three-mode toggle, extend to Categories/Saved), the persistence shape (`@AppStorage` under `dod.recipeListLayout` outside the `dod.settings.*` prefix because this is an in-tab control, not a Settings preference), the design-system-hosting rationale (avoid a `DODFeatureSearch → DODFeatureFeed` cross-feature dep), the list-row visual spec (60pt thumbnail, 1-line excerpt, `DODSpacing.sm` vertical padding), the toolbar placement on both tabs (trailing edge, toggle leading-side of gear on FeedView), the accessibility shape (current-state visible label, destination-aware spoken hint), and the L1 + L4 test surface delta. The `RecipeListLayout` enum exposes a `toggle()` method (mutating self → flips to the opposite case) so the button's tap handler is a one-liner.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (US-38 + AC-38.1..AC-38.6 inserted after US-36), `specs/dod-ios-app/clarifications.md` (CL-64 appended after CL-63), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the round-7 "Layout toggle" item to "Recently graduated").
  - **Source (commit 2):**
    - `Packages/DODDesignSystem/Sources/DODDesignSystem/RecipeListLayout.swift` (new — the `RecipeListLayout` enum with `.gallery` / `.list` cases, the `@AppStorage` key constant `"dod.recipeListLayout"`, the per-case `toggleIconName` computed property, the per-case `currentStateAccessibilityLabel` + `destinationActionHint` strings, the `toggle()` mutating method, and `nonisolated` static helpers for defensive `UserDefaults` round-trip used by the L1 tests).
    - `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift` (extend with `RecipeCard.ListRow` — sibling struct in the same file, declared as `extension RecipeCard { public struct ListRow: View { ... } }`; reuses the existing `timeChip(_:)` private helper by promoting it to a `static func` on `RecipeCard` so `ListRow` can call it; the existing `RecipeCard` struct body is byte-identical to today).
    - `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (add `@AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String = RecipeListLayout.gallery.rawValue` property; add a new `layoutToggleToolbarLink` private View; add a second `ToolbarItem(placement: .topBarTrailing)` carrying `layoutToggleToolbarLink` in the existing toolbar block, declared **before** `settingsToolbarLink` so visually the toggle sits to the leading side of the gear; modify the `list` private View to branch on the layout: `.gallery` keeps the existing `LazyVGrid` body byte-identical, `.list` renders a `LazyVStack` of `RecipeCard.ListRow` items wrapped in the same `recipeCardTap { onSelect(item) }` + `recipeCardContextMenu { onSave?(item) }` modifiers + the same `.task { await viewModel.loadMoreIfNeeded(currentItem: item) }` infinite-scroll hook).
    - `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (add `@AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String = RecipeListLayout.gallery.rawValue` property; add a new `.toolbar { }` block with a `ToolbarItem(placement: .topBarTrailing)` carrying the layout toggle button — same `#if os(iOS)` / `.automatic` fallback pattern; modify the `.results` case in `content` to branch on the layout: `.gallery` keeps the existing `LazyVGrid` body byte-identical, `.list` renders a `LazyVStack` of `RecipeCard.ListRow` items with the same `recipeCardTap` + `recipeCardContextMenu` modifiers).
  - **Tests (commit 2):**
    - `Packages/DODDesignSystem/Tests/DODDesignSystemTests/RecipeListLayoutTests.swift` (new L1 — `defaultIsGalleryWhenKeyAbsent`, `roundTripsGalleryAndListThroughUserDefaults`, `defensiveFallbackToGalleryOnMalformedRawValue`, `toggleFlipsGalleryToList`, `toggleFlipsListToGallery`).
    - `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift` (extend with two new test methods — `test_recipeCard_listRow_full` and `test_recipeCard_listRow_noTimeChip` — mirror of the existing `test_recipeCard_full` / `test_recipeCard_noTimeChip` baselines but for the new row variant; `record: .missing` lays the new PNGs down on the first iOS-sim test run under `__Snapshots__/SnapshotTests/`).
    - `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/FeedViewSnapshotTests.swift` (extend with `test_loadedFeed_listLayout_light_defaultDynamicType` and `test_loadedFeed_listLayout_dark_defaultDynamicType` — call the existing `Self.makeHostedFeed()` fixture, set `UserDefaults.standard.set(RecipeListLayout.list.rawValue, forKey: RecipeListLayout.storageKey)` before the snapshot, then reset to `.gallery` in `tearDown` so the other tests still see the default).
    - `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/SearchViewSnapshotTests.swift` (extend with `test_searchResults_listLayout_light_defaultDynamicType` and `test_searchResults_listLayout_dark_defaultDynamicType` — same pattern as the FeedView extension).
  - **Out of bounds:** the existing `RecipeCard` struct body (unchanged — `ListRow` is a sibling), the `recipeGridColumns(horizontalSizeClass:)` helper (unchanged — `.gallery` still uses it), the `recipeCardTap` + `recipeCardContextMenu` extensions (unchanged — compose on both layouts), the existing gallery-layout L4 baselines (unchanged — the default is still `.gallery`, so existing snapshots round-trip byte-identical), the `WidgetCard` siblings (widget layouts are fixed by the system widget family), the `SavedView` (Spencer's framing was Feed + Search only — Saved tab extension is a future task), the `CategoryRecipesView` (different content type — categories, not recipes), the gear-icon position on `FeedView` (AC-32.1's `.topBarTrailing` preserved — the toggle just sits to the leading side of the gear in the same group), `FeedView.navigationTitle("Recipes & Articles")` (US-37 / AC-37.1 preserved byte-identical), `SearchView.navigationTitle("Search")` (preserved byte-identical), the analytics events (no `layoutChanged` event — constitution §9 allowlist unchanged), the persistence schema (`@AppStorage` is `UserDefaults`-backed, no SwiftData touch), the deep-link grammar, the widget snapshot wire format, the `RecipeStore` API.
- **AC:** Implements AC-38.1, AC-38.2, AC-38.3, AC-38.4, AC-38.5, AC-38.6. Pins AC-32.1 (gear icon stays at trailing-edge of FeedView's `.topBarTrailing` group — toggle declared before so visually leading), AC-34.1 (`recipeCardContextMenu` Save flow continues to work on both layouts), AC-37.1 (FeedView nav title "Recipes & Articles" preserved), AC-1.3 (list row format preserved by `.gallery` default), CC-1 (accessibility — both layouts respect Dynamic Type + VoiceOver), CC-7 (performance — `LazyVStack` has the same lazy-realization semantics as `LazyVGrid`), CC-8 (iPad layouts — `.gallery` still uses `recipeGridColumns(horizontalSizeClass:)` for 3-col regular width; `.list` is single-column on both compact and regular per CL-64 since the row is designed for "denser scanning" not "wider columns"), CC-9 (2-column iPhone grid contract — preserved in `.gallery` default).
- **Deps:** T-640 (US-37 / Recipes & Articles tab rename) — already on `main`. T-650 reads `FeedView.swift`'s post-T-640 state. Source-wise no overlap with T-620 / T-630 (different packages or different files); spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected and the rebaser picks the next free CL/US/T slot (T-650 reserves CL-64, US-38, T-650).
- **Est:** 2.5h (new enum + persistence helper + ListRow view + two view edits + L1 + L4 baselines + spec entries — M per backlog sizing; the dual-tab placement is the heaviest part, the rest is plumbing).
- **||:** P10-layout-toggle (independent of every other Phase 10 task source-wise — T-650 owns the layout enum + RecipeCard.ListRow + FeedView's + SearchView's toolbar+body branch). No parallel agents running per the round-7 framing — all three prior round-7 PRs (T-620 / T-630 / T-640) merged before T-650 starts.

### T-660 — Tab-bar label truncation fix: short "Recipes" on bottom bar, full "Recipes & Articles" in screen header (US-37 amended, CL-65)
- **Scope:** T-640 (US-37 / CL-63) renamed the Recipes tab to "Recipes & Articles" in both `AppTab.title` (which drives the bottom-tab `Label(...)` AND every consumer that reads the tab's full content-typed name) and `FeedView.navigationTitle` (same string, sourced from `AppTab.feed.title`). The rename worked correctly for the screen header but introduced a user-visible regression at the bottom of the screen: the system tab bar item has a fixed-width slot (~80pt on standard iPhone widths in portrait at default Dynamic Type), and "Recipes & Articles" renders with an ellipsis as "Recipes & Arti...". The fix decouples the two strings: introduce a new `AppTab.tabLabel: String` computed property returning a tab-bar-appropriate short string per case (matches `title` for every case except `.feed`, which returns "Recipes" — the pre-T-640 wording, unambiguously paired with the `house` glyph); update `RootView.phoneTabs`'s `TabView` block to read `tabLabel` for the `Label(...)` declaration inside `.tabItem { }`; leave `title` and `FeedView.navigationTitle("Recipes & Articles")` unchanged so the screen header keeps the full content semantics. CL-65 captures the rationale, the considered alternatives (abbreviate the full string, `.minimumScaleFactor`, drop the label, alt short words, two-line labels, apply to iPad sidebar too, apply the convention universally), the why-new-property-and-not-shorter-title argument, the zero telemetry impact, the L4 snapshot baseline re-record scope (T-310's `TabBarSnapshotTests` iPhone baselines), and the coordination notes against T-670 / T-680 / T-690.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (AC-37.1 amended — original wording preserved with an amendment line pointing back to CL-65), `specs/dod-ios-app/clarifications.md` (CL-65 appended after CL-64), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the just-added round-8 "Tab-bar truncation" entry to "Recently graduated").
  - **Source (commit 2):**
    - `App/AppTab.swift` (add `tabLabel: String` computed property — `.feed → "Recipes"`, fallthrough `tabLabel == title` for every other case; doc comment on both `title` and `tabLabel` explaining the split and pointing to CL-65).
    - `App/RootView.swift` (one-line swap inside `phoneTabs`'s `TabView` block: `Label(tab.title, systemImage: tab.systemImage)` → `Label(tab.tabLabel, systemImage: tab.systemImage)`; the `iPadSplit` sidebar `List` keeps reading `tab.title` because sidebar rows have plenty of horizontal slack and the full content-semantics framing is appropriate there).
  - **Tests (commit 2):**
    - L4 snapshot baseline re-record: `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/TabBarSnapshotTests/*.png` (the eight iPhone 13 baselines + the eight iPad 12.9" baselines from T-310 / US-16 / AC-16.5). The DesignSystem-package `TabBarSnapshotTests` fixture already declares `Tab.feed.title == "Recipes"` locally (the fixture was not updated when T-640 renamed the App-side `AppTab.feed.title` — drift was tolerated because the App-side fixture pinning lived in `DODAppUnitTests/AppTabTests` which also was not updated), so the fixture stays byte-identical and the baselines stay byte-identical. The macro alignment is now correct-for-the-right-reason: the fixture's `Tab.feed.title == "Recipes"` matches the App's `AppTab.feed.tabLabel == "Recipes"`, which is what drives the bottom-tab `Label(...)` on the real app. If any iPhone baseline does drift (e.g. a font metric shift in the simulator runtime), re-record per the standard `record: .missing` workflow.
  - **Out of bounds:** the article-rendering path (`RecipeDetailViewModel.fetchAndParse()`, `ArticleBodyExtractor`, the `articleBodyHTML` SwiftData column, `PostKind`, `ArticleDetailView`, `markJSONLDFailed` — all preserved per CL-63), AC-37.2..AC-37.8 (PostKind classification, article rendering, save semantics — all preserved), AC-16.1 (tab order Recipes & Articles → Categories → Saved → Search — `AppTab.allCases` ordering unchanged), AC-16.4 (telemetry names stable — `AppTab.feed.telemetryName == "feed"` unchanged), the `house` glyph, the `RecipeRoute.recipe(item:)` grammar, the deep-link grammar (`dod://recipe/<id>`), the widget surfaces, the analytics events (no new event), `FeedView.navigationTitle("Recipes & Articles")` (preserved byte-identical), the iPad sidebar `Label(tab.title, ...)` in `RootView.iPadSplit` (preserved — sidebar rows have horizontal slack).
- **AC:** Implements the amended AC-37.1 per CL-65. Pins AC-37.2..AC-37.8 (all preserved byte-identical), AC-16.1 (order unchanged), AC-16.2 (`bookmark` glyph for Saved tab unchanged), AC-16.3 (in-recipe Save bookmark glyph unchanged), AC-16.4 (telemetry names stable), AC-16.5 (snapshot baseline coverage — fixture + baseline alignment realigned).
- **Deps:** T-640 (US-37 / Recipes & Articles tab rename) — already on `main`. T-650 (Gallery/List toggle) — already on `main` (T-660 doesn't touch any T-650-owned surface; `FeedView` and `SearchView` are unaffected because the tab-bar `Label(...)` lives on `RootView.phoneTabs`'s `TabView`, not on the feature views). Independent of T-630 / T-620.
- **Est:** 0.5h (one new computed property + one-line `RootView` swap + one AC amendment + one new CL + one task entry + one backlog graduation; the L4 baseline re-record is "verify byte-identical" not "redraw").
- **||:** P10-tab-label-fix (independent of every other Phase 10 / round-8 task source-wise — T-660 owns `App/AppTab.swift` + `App/RootView.swift`'s `phoneTabs` block exclusively). Coordination: T-670 (phantom searches, owns `Packages/DODFeatureSearch/**`), T-680 (Shopping List, new package), T-690 (Voice Mode, owns `Packages/DODFeatureRecipeDetail/**` Cook Mode surface) running in parallel — different files, no source-side collisions. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot (T-660 reserves CL-65, T-660 — no new US needed; the AC amendment lives under existing US-37).

### T-670 — Empty Recent section after Clear All; curated "Try" taps must not pollute Recent (US-29, CL-66, REG-19)
- **Scope:** Round-8 user report: after tapping "Clear All" on the Search tab's Recent section, three curated terms ("Bourbon", "Sweet Potato", "Brisket") remain visible. Root cause is two-fold: (1) tapping a curated "Try" suggestion pill (the round-7 `onCategoryTap` wiring set `viewModel.query = category.name` directly) routed the curated category name through the same `recents.record(...)` persistence path as a user-typed query, so curated category names silently leaked into Recent the first time the user tapped a pill; (2) `clearRecentSearches()` did not cancel any in-flight debounced search, so a `performSearch` that started just before Clear All could complete *after* the wipe and re-record the just-cleared term. Fix: add `SearchViewModel.selectCuratedSuggestion(_:)` which sets the query AND flips a new private `queryFromCuratedTap` flag; `performSearch()` skips `recents.record(...)` when the flag is set; `clearRecentSearches()` calls `debounceTask?.cancel()` as a defensive belt; `SearchView.onCategoryTap` routes through `selectCuratedSuggestion(_:)` rather than raw `query = ...`. `IdleSuggestionsView` already conditions the Recent section on `if !recents.isEmpty` (no fallback to Try-pill data) — the bug is not a view-side leak, it is a recording-path leak. CL-66 captures the full root cause + the fix shape; REG-19 pins the contract.
- **Files:**
  - **Spec/clarifications/tasks/backlog (commit 1):** `specs/dod-ios-app/spec.md` (REG-19 appended to the AC-T4 list under "Test pyramid"), `specs/dod-ios-app/clarifications.md` (CL-66 appended after CL-65), `specs/dod-ios-app/tasks.md` (this entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the round-8 "Clear All shows 3 phantom searches" entry to "Recently graduated" prose).
  - **Source (commit 2):**
    - `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchViewModel.swift` (add private `queryFromCuratedTap: Bool` flag reset in `query.didSet`; add `public func selectCuratedSuggestion(_ query: String)` that sets `query` then flips the flag; `clearRecentSearches()` calls `debounceTask?.cancel()` before `recents.clear()`; `performSearch()` wraps the `recents.record(trimmed)` + `recentSearches = recents.recent()` lines in `if !queryFromCuratedTap { ... }`).
    - `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` (`onCategoryTap` callback changes from `viewModel.query = category.name` to `viewModel.selectCuratedSuggestion(category.name)`; doc comment expanded to point at REG-19 / CL-66).
  - **Tests (commit 2):**
    - `Packages/DODFeatureSearch/Tests/DODFeatureSearchTests/SearchViewModelTests.swift` (new L1 `@Test func curatedTapDoesNotRecordRecentAndClearAllLeavesRecentEmpty()` — three curated taps ("Bourbon", "Sweet Potato", "Brisket") + assert recents empty; one typed query ("pasta") + assert recents == ["pasta"]; Clear All + assert recents empty; one more curated tap + assert recents still empty).
  - **Out of bounds:** `IdleSuggestionsView.swift` (already correct — Recent section conditioned on `if !recents.isEmpty`, no Try-pill fallback inside the Recent section; the bug is not view-side), `RecentSearches.swift` (storage layer is correct — `clear()` removes the UserDefaults key and `recent()` returns `[]`), `SearchView`'s `.results` / `.searching` / `.noResults` / `.offline` arms (unchanged), the filter chips (unchanged), `selectRecent(_:)` (preserved — recent-tap re-runs the search and IS the user's intent to re-find the term, so recording it on completion is correct; the `query.didSet` flag-reset path covers this), `clear()` (preserved — clears the field + items + state, separate from the recents-store clear), the L4 snapshot baselines (no view-tree change), the analytics events (constitution §9 allowlist unchanged — no new event), the deep-link grammar, the widget surfaces, every other package.
- **AC:** Implements REG-19 (the new pin under AC-T4). Pins AC-29.1 (curated "Try" tap routes through the query field — preserved), AC-29.2 (Clear All affordance — preserved + hardened against the in-flight race), AC-12.4 (recents persist across VM instances — unchanged for user-typed queries; only curated taps no longer persist), CL-49 (single-source-of-truth routing through the view-model — preserved).
- **Deps:** Round-7 T-500 (Clear All affordance) and T-580 (per-term context menu) — already on `main`. Independent of T-660 / T-680 / T-690 (different files in different packages).
- **Est:** 1h (one new method + one didSet line + one cancel call + one if-guard + one call-site swap + one L1 test + one CL + one REG + one task entry + one backlog graduation).
- **||:** P10-phantom-recents (independent of every other Phase 10 / round-8 task source-wise — T-670 owns `Packages/DODFeatureSearch/**` exclusively). Coordination: T-660 (tab-bar truncation, owns `App/AppTab.swift` + `App/RootView.swift`'s `phoneTabs` block), T-680 (Shopping List, new package), T-690 (Voice Mode, owns `Packages/DODFeatureRecipeDetail/**` Cook Mode surface) running in parallel — different files, no source-side collisions. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time; T-670 reserves CL-66, REG-19, T-670 — no new US (behavior change lives under existing US-29).

### T-690a — `VoiceReader` core: `AVSpeechSynthesizer` wrapper + audio session + mock-based L1 tests (US-40 / AC-40.2 + AC-40.4 + AC-40.6 + AC-40.7, CL-79)
- **Scope:** Round-3 dad "Cooking Voice Mode" backlog item, graduated as US-40 and split into two tasks. T-690a delivers **only** the standalone, unit-tested `VoiceReader` core — the `AVSpeechSynthesizer` wrapper with `speak(_:) / stop() / pause() / resume()`, lazy `.playback` + `.duckOthers` audio-session activation on first speak + deactivation on stop (per CL-79), and a `SpeechSynthesizing` protocol seam (with a thin `AVSpeechSynthesizer` adapter) so the reader is unit-testable without real audio. The reader uses the system-default voice for `Locale.current` per CL-79. **This task touches no Cook Mode UI, registers no App Intents, and adds no analytics event** — the toggle, the re-read-on-step-change driver, the four Siri intents, and the `voiceModeToggled` event all land in T-690b. The point of the split is a small, completable, sim-free unit: the reader's state machine is exercised entirely with a mock synthesizer.
- **Files:**
  - **Spec/clarifications/tasks (commit 1):** `specs/dod-ios-app/spec.md` (US-40 + AC-40.1..AC-40.8 inserted after US-39 — the ACs are tagged T-690a vs T-690b), `specs/dod-ios-app/clarifications.md` (CL-79 appended under a new "Phase 13 amendments (Voice Mode, 2026-05-27)" section after the Phase 12 summary), `specs/dod-ios-app/tasks.md` (this T-690a entry + the T-690b entry under Phase 10), `specs/dod-ios-app/backlog.md` (graduate the round-3 "Cooking Voice Mode" item with strike-through + a Recently-graduated reference to US-40 / CL-79 / T-690a/b). No constitution edit here — the §9 allowlist amendment for `voiceModeToggled` lands paired with T-690b (which is the task that actually adds the event), keeping the T-690a PR's source change a single new file + its test.
  - **Source (commit 2):** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/VoiceReader.swift` (new — the `SpeechSynthesizing` protocol (`speak(_:) / stop() / pause() / continueSpeaking()` + `isSpeaking` / `isPaused`), the `AVSpeechSynthesizer` adapter conforming to it, and the `VoiceReader` class wrapping a `SpeechSynthesizing` with `speak(_:) / stop() / pause() / resume()`; the audio-session activate/deactivate is wrapped in `#if os(iOS)` mirroring `SystemCookLiveActivityController`'s ActivityKit guard so the package still builds on the macOS `swift test` slice; doc comments point to US-40 / AC-40.2 + AC-40.4 + AC-40.6 + AC-40.7 / CL-79).
  - **Tests (commit 2):** `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/VoiceReaderTests.swift` (new — L1 with a `MockSpeechSynthesizer`: `speakEntersSpeakingState`, `stopReturnsToStoppedState`, `pauseEntersPausedState`, `resumeReturnsToSpeakingState`, `speakingNewTextWhileSpeakingStopsPriorUtteranceFirst` (asserts a stop precedes the new speak — the AC-40.7 interruption contract), plus a `speakRecordsTheSpokenText` assertion that the mock received the expected string).
  - **Out of bounds (explicitly NOT in T-690a — these are T-690b):** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeView.swift` (the Voice Mode toggle — AC-40.1), `CookModeViewModel.swift` (the re-read-on-step-change driver — AC-40.3), any `RecipeAppIntents` file (the four Siri intents — AC-40.5), `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift` (the `voiceModeToggled` event — AC-40.8), and `specs/constitution.md` (the §9 allowlist amendment — lands with T-690b).
- **AC:** Implements the reader-core slices of US-40 — AC-40.2 (the `speak(_:)` engine + system-default voice/locale), AC-40.4 (pause/resume), AC-40.6 (audio ducking — `.playback` + `.duckOthers`), AC-40.7 (speak-while-speaking interrupts the prior utterance). Produces the spec entries (US-40 + CL-79) that T-690b's wiring + intents + analytics ACs (AC-40.1, AC-40.3, AC-40.5, AC-40.8) trace to. Pins the constitution §9 "no raw user input strings to the network" posture (the reader is fully on-device — no egress at all) and the constitution §2 platform-guard pattern (the `#if os(iOS)` audio-session guard mirrors the ActivityKit guard).
- **Deps:** None (the reader core is self-contained in `DODFeatureRecipeDetail` and needs no other package). T-690b depends on T-690a (it consumes the `VoiceReader` surface).
- **Est:** 0h source-prereq / ~2.5h (the spec write — US-40 + CL-79 — plus one new source file + ~6 L1 mock-based tests; no sim needed).
- **||:** P10-voice-reader (independent of every other Phase 10 / round-8 task source-wise — T-690a owns `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/VoiceReader.swift` + its test file exclusively). Coordination: T-680 (Shopping List — dad, new `DODFeatureShoppingList` package + a later T-685 RecipeDetail toolbar extension on `RecipeDetailView.swift`, a *different* region of this package from the new `VoiceReader.swift`) and T-670 (phantom searches — Spencer, `Packages/DODFeatureSearch/**`) running in parallel — no source-side collisions. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot — T-690a reserves CL-79, US-40, T-690a/T-690b.

### T-690b — Cook Mode Voice Mode wiring: toggle + re-read driver + four Siri intents + `voiceModeToggled` analytics (US-40 / AC-40.1 + AC-40.3 + AC-40.5 + AC-40.8, CL-79)
- **Scope split (CL-81, round-8 batching):** T-690b is carved into a small in-app slice (this PR — `feat/T-690b-voice-wiring`) and a Siri/analytics follow-up (**T-690c**). **T-690b ships (in-app, AC-40.1 + AC-40.3 + the AC-40.5 control surface):** the Voice Mode toggle on `CookModeView`'s top bar, the re-read-on-step-change driver in `CookModeViewModel` (the on-screen Next/Previous + swipe already call `goNext()` / `goBack()`, which now re-`speak(_:)` the new step when Voice Mode is on, including the "All done — enjoy your meal" line on `isFinished`), and the four hands-free control methods on the view model — `advanceStep()` / `previousStep()` / `repeatCurrentStep()` / `pauseVoice()` — wired to `VoiceReader` and exercised in-app + by L1 tests. `endCookMode()` calls `VoiceReader.stop()` and clears `isVoiceModeEnabled` (AC-7.6). **Deferred to T-690c (AC-40.5 Siri exposure + AC-40.8):** the four `RecipeAppIntents` + App Shortcuts donation (a thin adapter over the now-tested view-model methods) and the `voiceModeToggled(recipeID:enabled:)` analytics event + constitution §9 amendment. The full T-690b scope below is preserved as the combined T-690b/T-690c plan; items (3) and (4) move to T-690c.
- **Scope:** Wire the T-690a `VoiceReader` into the Cook Mode surfaces and add the hands-free command layer. (1) Add the Voice Mode toggle to `CookModeView`'s control bar per AC-40.1 (`speaker.wave.2` / `.fill`, `cook-mode-voice-toggle`, off-by-default + not-persisted per CL-79). (2) Drive `VoiceReader.speak(_:)` from `CookModeViewModel` whenever the current step changes while Voice Mode is on — on-screen Next/Previous, Siri command, or toggle-on landing on the first step — per AC-40.3, including the "All done" completion line on `isFinished`. (3) Register the four `RecipeAppIntents` (Next step / Previous step / Repeat / Pause) per AC-40.5, donating App Shortcuts so Siri surfaces the phrases; the intents target the active Cook Mode session and route Next/Previous through the same `goNext()` / `goBack()` the on-screen controls use. (4) Add the `voiceModeToggled(recipeID:enabled:)` analytics event per AC-40.8 and amend constitution §9's allowlist. Voice command actions emit no telemetry.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeView.swift` (extend — the Voice Mode toggle on the control bar; on-toggle reads the current step / on-untoggle stops the reader + deactivates the session).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeViewModel.swift` (extend — hold a `VoiceReader`, an `isVoiceModeEnabled` flag, and the re-read-on-step-change driver feeding the current step text into `VoiceReader.speak(_:)`; fire the `voiceModeToggled` event on flip).
    - A `RecipeAppIntents` file in `Packages/DODFeatureRecipeDetail/**` (new — the four `AppIntent`s + the `AppShortcutsProvider` registration; guarded `#if canImport(AppIntents)` / availability as needed, mirroring the deep-link / App Intent infrastructure REG-10 already established).
    - `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift` (extend — new `case voiceModeToggled(recipeID: Int, enabled: Bool)` + its `name` (`"voice_mode_toggled"`) + `payload` (`recipe_id` + `enabled`) entries per the existing event pattern).
    - `specs/constitution.md` (§9 amendment — append `voiceModeToggled` to the allowlist with the 2026-05-27 / T-690b dating, matching the prior amendment-history pattern; the App Privacy questionnaire mapping table is unchanged — the event is "Usage Data — Product Interaction").
  - **Tests (commit 2):** `CookModeViewModelTests.swift` (extend — Voice Mode on reads the current step; advancing a step while on re-reads; toggling off stops the reader; `voiceModeToggled` fires with the right payload on flip — using an injected fake `VoiceReader` / mock synthesizer + `RecordingTelemetryTransport`). `AnalyticsEventTests.swift` (extend — `voiceModeToggled_emitsExpectedNameAndParameters`). Intent-level coverage asserts each intent invokes the expected Cook Mode action. Re-record any `CookModeView` L4 baseline the new toggle button affects.
- **AC:** Implements AC-40.1 (toggle), AC-40.3 (re-read on step change), AC-40.5 (four Siri intents), AC-40.8 (`voiceModeToggled` analytics + §9 amendment). Consumes the T-690a `VoiceReader` core (AC-40.2 / AC-40.4 / AC-40.6 / AC-40.7). Pins AC-7.4 (the on-screen Next/Previous still drive step navigation — the intents reuse the same `goNext()` / `goBack()`), REG-10 (the App Intent / deep-link round-trip infrastructure the intents build on), AC-36.5 (the new event is gated by the opt-out toggle like every other event).
- **Deps:** T-690a (the `VoiceReader` surface this task wires in) — must merge first.
- **Est:** ~4h (the toggle + view-model driver + four intents + the App Shortcuts registration + the analytics event + §9 amendment + the L1 coverage + one re-recorded L4 baseline; the intent donation + the per-session driver are the bulk).
- **||:** P10-voice-reader (sequential after T-690a within the cluster). Independent of every other Phase 10 / round-8 task source-wise except for the `AnalyticsEvent.swift` extension (a one-case additive edit) — coordinate with any other in-flight task that also extends `AnalyticsEvent` (e.g. T-687's Shopping List analytics) by picking distinct cases; the two events are orthogonal. Coordination: T-680 / T-685 (Shopping List RecipeDetail toolbar extension on `RecipeDetailView.swift` — a different file from `CookModeView.swift` / `CookModeViewModel.swift`) — no source-side collisions. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` (and `constitution.md` §9 if T-687 lands concurrently) are expected at merge time; the later PR folds both events into the §9 allowlist sentence.

### T-690c — Voice Mode Siri intents + voice telemetry: four `AppIntent`s + `voiceModeToggled` / `voiceCommandFired` analytics (US-40 / AC-40.5 + AC-40.8, CL-83)
- **Scope:** The Siri/analytics follow-up CL-81 carved off T-690b. Builds the four hands-free `AppIntent`s as a thin adapter over the already-tested `CookModeViewModel` control surface (`advanceStep()` / `previousStep()` / `repeatCurrentStep()` / `pauseVoice()` — all landed in T-690b). (1) **Four App Intents** — `NextStepIntent` → `advanceStep()`, `PreviousStepIntent` → `previousStep()`, `RepeatStepIntent` → `repeatCurrentStep()`, `PauseVoiceIntent` → `pauseVoice()` — registered with natural-language phrases via the existing `DODShortcuts` `AppShortcutsProvider` ("next step" / "next" / "go forward", "previous step" / "back", "repeat" / "say that again", "pause"). (2) **How the intents reach the live Cook Mode VM (CL-83):** a new `VoiceCommandBus` singleton in `DODFeatureRecipeDetail` (mirroring the US-10 `DeepLinkDispatcher` pattern) holds a `weak` reference to the active `CookModeViewModel`; `beginCookMode()` registers the VM as the handler and `endCookMode()` unregisters it, so the bus only ever drives the foreground Cook Mode session and never retains a dead VM. Each intent calls `VoiceCommandBus.shared.dispatch(.next/.previous/.repeat/.pause)` from `perform()`; the bus hops to `@MainActor` and forwards to the registered VM's matching method (a no-op when Cook Mode isn't foreground — Siri can fire a phrase from the lock screen with no active session). The intents themselves carry no `recipe` parameter (unlike the US-10 `OpenRecipeIntent`) — they act on whatever step the live session is on. (3) **Telemetry:** new `voiceCommandFired(command:)` event fired from each intent (`command` is the fixed enum string `"next"` / `"previous"` / `"repeat"` / `"pause"` — never the raw spoken phrase), plus `voiceModeToggled(on:)` for the in-app toggle (fired from `CookModeViewModel.setVoiceMode(_:)`); constitution §9 allowlist amended for both.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/VoiceCommandBus.swift` (new — the `@MainActor @Observable` singleton command bus + the `VoiceCommand` enum; `nonisolated dispatch(_:)` mirroring `DeepLinkDispatcher`).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeViewModel.swift` (extend — register/unregister with `VoiceCommandBus` in `beginCookMode()` / `endCookMode()`; fire `voiceModeToggled(on:)` from `setVoiceMode(_:)`).
    - `App/VoiceCommandIntents.swift` (new — the four `AppIntent`s; each calls `VoiceCommandBus.shared.dispatch(...)` + fires `voiceCommandFired`).
    - `App/RecipeAppIntents.swift` (extend — register the four intents' phrases on the existing `DODShortcuts` `AppShortcutsProvider`).
    - `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift` (extend — `case voiceModeToggled(on: Bool)` (`"voice_mode_toggled"`, payload `{ on }`) + `case voiceCommandFired(command: VoiceCommandName)` (`"voice_command_fired"`, payload `{ command }`) where `VoiceCommandName` is a closed `String`-raw enum so no free text can leak).
    - `specs/constitution.md` (§9 amendment — append `voiceModeToggled` + `voiceCommandFired` to the allowlist with the 2026-05-27 / T-690c dating; App Privacy questionnaire mapping unchanged — both are "Usage Data — Product Interaction").
  - **Tests (commit 2):** L1 per intent (a fake `CookModeViewModel`-style handler registered on the bus asserts the right method fires) + `voiceCommandFired` / `voiceModeToggled` payload-shape tests in `AnalyticsEventTests.swift` (assert the closed enum-string set, no free text).
- **AC:** Implements AC-40.5 (the four Siri intents — the in-app control surface they call landed in T-690b) and AC-40.8 (`voiceModeToggled` + `voiceCommandFired` analytics + §9 amendment). Pins AC-7.4 (Next/Previous route through `goNext()` / `goBack()` via the VM methods), REG-10 (the App Intent / `AppShortcutsProvider` infrastructure US-10 established and this extends), AC-36.5 (both new events gated by the opt-out toggle like every other event). Siri intents can't be exercised in the sim without a device — the L1 tests + a clean build are the verification.
- **Deps:** T-690b (the `CookModeViewModel` control surface + the in-app toggle the events fire from) — must merge first.
- **Est:** ~30m (the four thin intents + the command bus + register/unregister hooks + two analytics events + the L1 coverage; no UI, no L4 re-record).
- **||:** P10-voice-reader (sequential after T-690b within the cluster). Touches App Intents — per CONTRIBUTING.md § "Does my PR need E2E?" this PR carries the `e2e` label. Independent of every other round-8 task source-wise except the additive `AnalyticsEvent.swift` extension — coordinate with any other in-flight task that also extends `AnalyticsEvent` (e.g. T-687's Shopping List analytics) by picking distinct cases. Coordination: T-680b (`ShoppingListView` — dad, new `DODFeatureShoppingList` package + spec edits) running in parallel; no source-side collisions (different packages). Spec-file collisions on `clarifications.md` / `tasks.md` / `constitution.md` §9 are expected at merge time and the rebaser picks the next free CL/T slot — T-690c lands as CL-83 (renumbered from CL-82 on merge — CL-82 was taken by T-680b), T-690c (no new US; the work lives under existing US-40).

---

## Phase 12 — Shopping List feature (2026-05-27)

Round-3 dad backlog item "Shopping list from saved recipes" graduates through the spec-orchestrator pipeline. T-680 lands the spec amendment (US-39 + 12 CLs); T-681..T-689 implement the feature across nine sub-tasks. Cluster owner: dad. Parallelism tag: `P12-shopping`. Coordination with the rest of the round-8 parallels (T-660 already merged, T-670 in-flight, T-690 pending) is captured per-task below; no source-side collisions because each parallel owns a different package family. Spec-file collisions on `clarifications.md` / `spec.md` / `tasks.md` / `backlog.md` are expected at merge time and the rebaser picks the next free CL/US/T slot (T-680 reserves CL-67..CL-78, US-39, T-680..T-689).

### T-680 — Shopping List spec amendment (US-39, CL-67..CL-78)
- **Scope:** Pure spec-only PR. Adds US-39 (Shopping list from saved recipes) with AC-39.1..AC-39.12 to `spec.md`; appends CL-67..CL-78 to `clarifications.md` under a new "Phase 12 amendments" section; adds the T-680..T-689 cluster + Summary block update to `tasks.md`; graduates the round-3 "Shopping list from saved recipes" backlog entry with strike-through + a Recently-graduated section reference in `backlog.md`. No source code, no test files, no constitution edits (the §9 allowlist amendment for the two new analytics events lands paired with T-687, not here — keeps the spec-amendment PR docs-only).
- **Files:**
  - **Spec/clarifications/tasks/backlog (single commit cluster):** `specs/dod-ios-app/spec.md` (US-39 + AC-39.1..AC-39.12 inserted after US-38; REG-23 inserted in the AC-T4 test pyramid block), `specs/dod-ios-app/clarifications.md` (CL-67..CL-78 appended under a new "Phase 12 amendments (Shopping List, 2026-05-27)" section header after CL-65), `specs/dod-ios-app/tasks.md` (this Phase 12 section + Summary block update), `specs/dod-ios-app/backlog.md` (graduate the round-3 "Shopping list from saved recipes" item with strike-through + a Recently-graduated entry).
- **AC:** Implements no spec ACs directly; produces the spec entries that AC-39.1..AC-39.12 + REG-23 trace to. Pins constitution §11 ("PR cites the spec.md section(s) it implements") by being the spec.md section everything else cites.
- **Deps:** None.
- **Est:** 0h source / 4h docs (12 CLs + 12 ACs + a cluster of 10 task entries + backlog graduation; the writing is the work).
- **||:** P12-shopping (this PR; T-681..T-689 are the implementation parallels per the entries below).

### T-680a — Shopping List logic core: classifier + fraction-aware aggregator + L1 tests (CL-80, US-39 / AC-39.4 + AC-39.7)
- **Scope:** Pure-logic slice of US-39, carved forward per CL-80 so the algorithmic core lands fast and fully unit-tested ahead of the UI (T-680b). Two value types in `DODSupport`, no view / no persistence / no network: (1) `IngredientAisleClassifier` — the CL-67 static keyword-map classifier (`enum Aisle: String, CaseIterable` co-located in the file per CL-80; a `[String: Aisle]` literal of ~60 common ingredient stems; `static func classify(_:) -> Aisle` doing case-insensitive substring matching, `.other` fallback). (2) `IngredientAggregator` — `static func aggregate(_ ingredients: [RecipeIngredient]) -> [AggregatedItem]` that sums same-unit + same-name lines via `FractionRenderer.renderQuantity` (CL-70's option (b) as a reusable utility), keeps differing-unit / unparseable / differing-name lines split, and tags each item with its `Aisle`. Adds DODDomain as a DODSupport dependency (acyclic — DODDomain has no DODSupport dependency) so the aggregator can take the `RecipeIngredient` raw-text type. Does NOT change the v1 shipped UI contract (CL-77 per-recipe rows stay the default; the aggregator is a capability T-680b may opt into).
- **Files:**
  - **Spec (commit 1):** `specs/dod-ios-app/clarifications.md` (CL-80 appended after CL-78), `specs/dod-ios-app/tasks.md` (this entry under Phase 12). No new US (US-39 already covers it); no AC amendments (the logic core implements the algorithmic substrate of AC-39.4 + AC-39.7 without changing their text).
  - **Source (commit 2):** `Packages/DODSupport/Sources/DODSupport/IngredientAisleClassifier.swift` (new — the `Aisle` enum + the keyword map grouped by aisle with per-aisle comment blocks + `classify(_:)`). `Packages/DODSupport/Package.swift` (update — `DODDomain` dependency added to the `DODSupport` target).
  - **Source (commit 3):** `Packages/DODSupport/Sources/DODSupport/IngredientAggregator.swift` (new — the `AggregatedItem` result type + `aggregate(_:)` + the leading-quantity/unit parser that reuses `FractionRenderer.renderQuantity` for output).
  - **Tests (commits 2 + 3):** `Packages/DODSupport/Tests/DODSupportTests/IngredientAisleClassifierTests.swift` (new — 20+ golden cases: each aisle, the `.other` fallback, case-insensitivity). `Packages/DODSupport/Tests/DODSupportTests/IngredientAggregatorTests.swift` (new — 10+ cases: same-unit merge, differing-unit no-merge, fraction math, empty input, single item).
- **AC:** Implements the algorithmic substrate of AC-39.4 (the classifier the render path groups by) and offers AC-39.7 an optional rolled-up share path (the aggregator). Pins AC-39.12 (no network egress — both types are pure). Constitution §6 L1 mandate (every domain transform has a unit-test home).
- **Deps:** T-680 (spec entries this implements against). Lands the CL-67 classifier early; T-681's planned `Aisle.swift`-in-DODDomain placement is reconciled by T-680b/T-681 per CL-80 (mechanical hoist, no behavior change).
- **Est:** 0.5h (two bounded pure types + golden tests; the keyword-map curation is the only real work).
- **||:** P12-shopping. T-680b is the UI follow-up (`ShoppingListView` + `ShoppingListItem` `@Model` + design-system primitives — the T-681..T-689 entries below are the full plan T-680b draws from). T-680a owns `Packages/DODSupport/Sources/DODSupport/IngredientAisleClassifier.swift` + `IngredientAggregator.swift` exclusively. Coordination: T-690a (VoiceReader core) runs in parallel in a different package; spec-file collisions on `clarifications.md` / `tasks.md` are expected at merge time and the rebaser picks the next free CL/T slot (T-680a reserves CL-80, T-680a — CL-79 was taken by T-690a's Voice Mode CL).

### T-680b — Shopping List UI core: `ShoppingListView` + view-model with mock data + L1/L4 tests (CL-82, US-39 / AC-39.1 + AC-39.4 + AC-39.5 + AC-39.11)
- **Scope:** The SwiftUI surface slice of US-39, carved down per CL-82 so the view + view-model land previewable ahead of the persistence/entry/share wiring (deferred to T-680c). Builds `ShoppingListView` + `ShoppingListViewModel` driven by **mock data** (no persistence, no entry surfaces, no recipe-picker, no share). The view renders a sectioned `List` grouped by store aisle (per-recipe rows, NOT aggregated — CL-70/CL-77/CL-82), one section per non-empty `IngredientAisleClassifier.Aisle` in `allCases` declaration order with a per-aisle SF Symbol glyph header; each row is an ingredient text + recipe-title sub-label + a leading checkbox circle (`circle`/`checkmark.circle.fill`, tap → strikethrough, AC-39.5) and a trailing "I already have this" swipe action; an `EmptyState` (`cart` glyph + AC-39.1 copy) when the list is empty. Check + already-have state is ephemeral (in-memory `Set<ID>` on the view-model, reset on re-init per CL-82 — the SwiftData `isChecked` round-trip is T-680c). Groups by the **six-case** `Aisle` shipped by T-680a (CL-80); the nine-case render set + the `Aisle`→`DODDomain` hoist are a T-680c/T-681 mechanical reconciliation. Lands inside the existing `DODFeatureSaved` package (already has the `DODSupport` + `DODDesignSystem` + `DODDomain` deps this slice needs) per CL-82's package-placement decision; T-680c extracts the `DODFeatureShoppingList` package when it adds persistence + entry + share.
- **Files:**
  - **Source (commit 2):** `Packages/DODFeatureSaved/Sources/DODFeatureSaved/ShoppingListView.swift` (new — the sectioned `List`, the inline aisle-section header with per-aisle glyph, the row with leading checkbox + trailing already-have swipe, the empty state, a `#Preview`). `Packages/DODFeatureSaved/Sources/DODFeatureSaved/ShoppingListViewModel.swift` (new — `@Observable @MainActor`; holds the classified rows grouped by aisle, the ephemeral `checkedIDs` + `alreadyHaveIDs` sets, the toggle methods + derived counts, and a `static var mock` fixture of 3 recipes' worth of ingredient lines classified through `IngredientAisleClassifier`).
  - **Tests (commit 2):** `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/ShoppingListViewModelTests.swift` (new — L1 Swift Testing: grouping into aisle sections in store-walk order, empty-aisle omission, check toggle flips membership + count, already-have toggle removes the row from the still-need list, counts). `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/ShoppingListViewSnapshotTests.swift` (new — L4 snapshot of `ShoppingListView` with the mock fixture, light + dark, `record: .missing` per the SavedView baseline pattern).
- **AC:** Implements AC-39.1 (empty state), AC-39.4 (aisle grouping + store-walk order + per-aisle glyphs — render side), AC-39.5 (per-row check toggle + strikethrough — the ephemeral half), AC-39.11 (VoiceOver row labels). Defers AC-39.2 / AC-39.3 (entry surfaces), AC-39.6 (clear-all toolbar), AC-39.7 (share), AC-39.8 (persistence), AC-39.10 (analytics) to T-680c.
- **Deps:** T-680 (spec) + T-680a (the `IngredientAisleClassifier` + `Aisle` this view groups by).
- **Est:** 30 min (mock-data-only view + view-model + L1/L4; deliberately small per CL-82).
- **||:** P12-shopping. T-680b owns the two new `ShoppingListView*.swift` files in `DODFeatureSaved` exclusively (additive — no edits to `SavedView.swift` / `SavedViewModel.swift`). **T-680c** (new — wires the entry surfaces, the recipe-picker sheet, the `UIActivityViewController` share, the `ShoppingListItem` SwiftData persistence, and the `DODFeatureShoppingList` package extraction) is the follow-up that turns this mock-data view into the shipped feature; it draws from the full T-681..T-689 plan below. Coordination: T-690b (Voice Mode Cook Mode wiring) runs in parallel in `DODFeatureRecipeDetail` — different package, no source-side collisions; spec-file collisions on `clarifications.md` / `tasks.md` are expected at merge time (T-680b reserves CL-82, T-680b).

### T-680c — Shopping List entry point + recipe picker + iMessage share (CL-85, US-39 / AC-39.2 + AC-39.3 + AC-39.7 — completes US-39)
- **Scope:** The reachability + share slice that makes US-39 end-to-end usable, wiring the T-680b mock-data view (CL-82) to real saved recipes and a share surface. Three additive pieces, all in `DODFeatureSaved` (the package T-680b's view already lives in — the CL-73 `DODFeatureShoppingList` extraction is deferred as a non-blocking mechanical move): (1) a **Saved-tab toolbar button** ("Make Shopping List", SF Symbol `cart`, accessibility id `saved-make-shopping-list`) rendered in `SavedView`'s `.loaded` state that presents a recipe-picker sheet (CL-85 decision 1); (2) a **`ShoppingListBuilderSheet`** — a multi-select `List` of the Saved view-model's already-loaded `recipes` (leading `circle`/`checkmark.circle.fill` toggle per row, "Build List" toolbar button disabled until ≥1 selected, "Cancel" to dismiss) that hands the selected `[Recipe]` back via a closure (CL-85 decision 2); the selected recipes construct a `ShoppingListViewModel(recipes:)` via the **existing T-680b convenience initializer** (per-recipe rows, classified through `IngredientAisleClassifier` — no new construction path, CL-85 decision 4) and `SavedView` pushes `ShoppingListView` onto its existing `NavigationStack`; (3) a **"Share via iMessage"** button on `ShoppingListView` (SF Symbol `square.and.arrow.up`, accessibility id `shopping-list-share`) implemented as a SwiftUI **`ShareLink`** wrapping the `String` from a new **`ShoppingListFormatter.shareText(_:)`** (Markdown: "Shopping List" header + per-aisle blocks in store-walk order + `- <ingredient> (<recipe>)` lines), shown only when the list is non-empty (CL-85 decision 3). The share text **excludes checked + already-have rows** (the still-need subset — a deliberate, CL-85-recorded deviation from CL-72's full-list snapshot, reversible via a single `includeChecked` flag). Does NOT add SwiftData persistence, the `ShoppingListItem` `@Model`, analytics events, the per-recipe-detail `cart.badge.plus` action, the in-grid AC-39.3 selection mode, or the iPad-sidebar AC-39.9 row (those remain T-681..T-689 / T-685 / T-682 / T-687 concerns).
- **Files:**
  - **Spec (commit 1):** `specs/dod-ios-app/clarifications.md` (CL-85 appended under a new "Phase 14 amendments (Shopping List entry + picker + share, 2026-05-27)" section), `specs/dod-ios-app/tasks.md` (this entry under Phase 12). No new US (US-39 already covers it — this completes it); no AC amendments (the entry/picker/share realize AC-39.2 / AC-39.3 / AC-39.7's intent without changing their text; the share-text checked/already-have exclusion is recorded as the CL-85 deviation from CL-72).
  - **Source (commit 2):** `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift` (edit — add the "Make Shopping List" toolbar button + the `.sheet` presentation of `ShoppingListBuilderSheet` + the `navigationDestination`/state that pushes `ShoppingListView` from the built recipes). `Packages/DODFeatureSaved/Sources/DODFeatureSaved/ShoppingListBuilderSheet.swift` (new — the multi-select picker sheet). `Packages/DODFeatureSaved/Sources/DODFeatureSaved/ShoppingListFormatter.swift` (new — `static func shareText(_:)` building the aisle-grouped Markdown from the view-model's still-need visible+unchecked rows). `Packages/DODFeatureSaved/Sources/DODFeatureSaved/ShoppingListView.swift` (edit — add the `ShareLink` "Share via iMessage" toolbar button gated on non-empty).
  - **Tests (commit 2):** `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/ShoppingListBuilderSheetTests.swift` (new — L1: picker selection → `ShoppingListViewModel(recipes:)` construction explodes the selected recipes' ingredients into per-recipe rows; the build path drops nothing for ≥1 selection). `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/ShoppingListFormatterTests.swift` (new — L1: `shareText(_:)` emits aisle headers in store-walk order, one `- <ingredient> (<recipe>)` line per row, excludes already-have rows, excludes checked rows, and renders the empty-list case as just the header). Update `SavedViewSnapshotTests` baselines if the new toolbar button changes `SavedView`'s `.loaded` layout (the button lives in the nav-bar toolbar, so the content grid is unchanged — baselines are expected to hold).
- **AC:** Completes AC-39.2 + AC-39.3 (the entry → picker → build-list path — the picker-sheet realization of the multi-recipe add), AC-39.7 (share via the system share sheet, plain text, no `MessageUI` — `ShareLink`). Consumes the T-680b `ShoppingListView` + `ShoppingListViewModel(recipes:)` (CL-82) + the T-680a `IngredientAisleClassifier` (CL-80). With T-680a + T-680b, makes US-39 reachable end-to-end (Saved tab → picker → aisle-grouped list → share).
- **Deps:** T-680 (spec) + T-680a (the classifier the construction path runs ingredients through) + T-680b (the view + view-model + the `ShoppingListViewModel(recipes:)` initializer this wiring feeds).
- **Est:** 35 min (additive entry button + picker sheet + share + formatter + L1 tests; reuses the T-680b view + initializer).
- **||:** P12-shopping. T-680c edits `SavedView.swift` + `ShoppingListView.swift` and adds `ShoppingListBuilderSheet.swift` + `ShoppingListFormatter.swift` (+ their tests) in `DODFeatureSaved`. Coordination: T-690c (Voice Mode Siri intents) runs in parallel in `DODFeatureRecipeDetail` — different package, no source-side collisions; spec-file collisions on `clarifications.md` / `tasks.md` are expected at merge time and T-680c's CL is **pre-assigned CL-85** (not next-free) to avoid a CL collision with the parallel T-690c work. T-680c reserves CL-85, T-680c.

### T-681 — Aisle classifier + domain types + L1 tests (CL-67, US-39 / AC-39.4 + AC-39.10)
- **Scope:** Add the pure value types: `Aisle` enum (cases: produce, dairy, meatSeafood, bakery, frozen, pantry, spices, beverages, other; raw value String per CL-74) in `DODDomain`; `IngredientAisleClassifier` enum with `static func classify(_ ingredientText: String) -> Aisle` in `DODSupport` per CL-67 (~80-entry static keyword map, deterministic tokenization, locale-aware lowercasing). L1 unit tests against ~30 representative ingredient strings sampled from the live dutchovendaddy.com recipe corpus.
- **Files:**
  - **Source (commit 1):** `Packages/DODDomain/Sources/DODDomain/Aisle.swift` (new — the enum + raw-value strings + doc comments pointing to CL-67 / CL-74). `Packages/DODSupport/Sources/DODSupport/IngredientAisleClassifier.swift` (new — the static keyword map + the `classify(_:)` function + the tokenizer; ~80 entries grouped by aisle with per-aisle comment blocks per CL-67's curation rationale).
  - **Tests (commit 2):** `Packages/DODSupport/Tests/DODSupportTests/IngredientAisleClassifierTests.swift` (new — ~30 L1 cases: 5 per common aisle, 3 edge cases for the `.other` fallback, a fraction-handling case `"½ cup diced yellow onion" → .produce`, a compound-name case `"all-purpose flour" → .pantry`, a brand-name case `"Crisco vegetable shortening" → .other` documenting the expected miss, a Turkish-locale lowercasing edge case so the test catches a future locale regression).
- **AC:** Pins AC-39.4 (aisle grouping render — the enum's case set drives the AC-39.4 section ordering), AC-39.10 (telemetry payload — the raw values are the strings emitted on `shoppingListItemAdded`). Pins CL-67's escalation trigger (the L1 tests assert the `.other` share on the 30-case fixture set stays below the documented 15% threshold for the curated v1 corpus; a future test extension can include a 100-case live-API sample for nightly miss-rate auditing).
- **Deps:** T-680 (spec entries this task implements against — must merge first to give the AC references something to cite).
- **Est:** 2.5h (the static keyword map's curation is the heavy lift; the classifier + tests are bounded).
- **||:** P12-shopping (independent of every other T-68N task source-wise — T-681 owns `Packages/DODDomain/Sources/DODDomain/Aisle.swift` + `Packages/DODSupport/Sources/DODSupport/IngredientAisleClassifier.swift` exclusively).

### T-682 — Persistence: `ShoppingListItem` `@Model` + SchemaV4 migration + L1 migration test (CL-74, US-39 / AC-39.8)
- **Scope:** Add the new `ShoppingListItem` `@Model` class in `DODPersistence` with the CL-74 shape (`recipeID: Int`, `recipeTitle: String`, `ingredientText: String`, `aisleRaw: String`, `isChecked: Bool`, `addedAt: Date`). Bump the migration plan from V3 to V4: a new `SchemaV4` enum declaring `models: [...everything V3 has, ShoppingListItem.self]` and a lightweight migration stage `V3 → V4` since no existing entity is touched. Recreate the previously-deleted `SchemaV4.swift` (currently a comment-only marker per the T-640 in-place column trap) as the real V4 stage now that we have a legitimately additive entity. Add an L1 migration test mirroring `MigrationV3Tests.V2_to_V3_lightweightMigration`.
- **Files:**
  - **Source (commit 1):** `Packages/DODPersistence/Sources/DODPersistence/ShoppingListItem.swift` (new — the `@Model` class per CL-74's shape; includes the `aisle: Aisle { Aisle(rawValue: aisleRaw) ?? .other }` computed accessor and the doc comment pointing to CL-74). `Packages/DODPersistence/Sources/DODPersistence/SchemaV4.swift` (rewrite — the previously-comment-only marker becomes the real V4 stage now that the `ShoppingListItem` brand-new-entity case sidesteps the T-640 duplicate-checksum trap; doc comments explain the difference between "new entity" and "new column on existing entity" so a future contributor doesn't re-trigger T-640's footgun). `Packages/DODPersistence/Sources/DODPersistence/SchemaV1.swift` (update — `MigrationPlan.schemas` appends `SchemaV4.self`; `MigrationPlan.stages` appends `.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)`; the doc comment block's V3-to-V4 row gets a real "V3 → V4: lightweight (V4 = V3 + `ShoppingListItem`)" entry).
  - **Tests (commit 2):** `Packages/DODPersistence/Tests/DODPersistenceTests/MigrationV4Tests.swift` (new — `V3_to_V4_lightweightMigration`: open V3 container with a `CachedRecipe` + `CachedListPage` + `CachedImage`, close, reopen at V4, assert (i) V3 rows intact and queryable, (ii) the new `ShoppingListItem` entity exists and is empty, (iii) a freshly-inserted `ShoppingListItem` round-trips through `try modelContext.save()`).
  - **Persistence docs:** `Packages/DODPersistence/MIGRATION.md` (update — append a "V3 → V4 (Phase 12, T-682)" section documenting the new-entity case + the CL-74 reference).
- **AC:** Implements AC-39.8 (persistence across launches), AC-39.12 (no network egress — the persistence path is bounded to SwiftData), CL-74 (the migration shape). Pins R-5 (the additive-only schema-evolution rule MIGRATION.md established), the existing V1/V2/V3 migration test contract (new test follows the same shape).
- **Deps:** T-681 (the `Aisle` enum lives in DODDomain and the persistence layer's `aisle: Aisle` computed accessor needs the type) + T-680 (spec entries).
- **Est:** 2h (the new entity is bounded, the migration stage is lightweight, the test mirrors an existing one).
- **||:** P12-shopping (independent of T-683 / T-684 / T-685 / T-687 / T-688 / T-689 source-wise; T-684 has a `Deps:` on T-682 because the view model `@Query`s against `ShoppingListItem`).

### T-683 — DesignSystem primitives: `ShoppingListRow` + `AisleSectionHeader` + snapshot baselines (US-39 / AC-39.4 + AC-39.5)
- **Scope:** New SwiftUI components in `DODDesignSystem/Components/`: `ShoppingListRow` (a single row with leading-edge toggle circle + ingredient text + dimmer recipe-title sub-label + strikethrough variant for the checked state) and `AisleSectionHeader` (an aisle name + SF Symbol glyph per AC-39.4's aisle-to-glyph mapping). Each component gets an L4 snapshot baseline in `DODDesignSystemTests/SnapshotTests.swift` mirroring the existing per-component pattern (light + dark, default Dynamic Type, iPhone 13 baseline + iPad 12.9" + AX5 variants per the L4 contract).
- **Files:**
  - **Source (commit 1):** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/ShoppingListRow.swift` (new — the row primitive; takes `ingredientText: String`, `recipeTitle: String`, `aisle: Aisle`, `isChecked: Bool`, `onToggle: () -> Void` parameters; renders the leading circle + the text + the sub-label + the strikethrough decoration when checked; reuses `DODColor.surfaceElevated` / `DODColor.label` / `DODColor.labelSecondary` tokens; reuses `DODSpacing.md` for vertical rhythm). `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/AisleSectionHeader.swift` (new — the section header primitive; takes `aisle: Aisle` parameter; renders the aisle name + glyph per the per-aisle SF Symbol mapping in AC-39.4; reuses `DODColor.label` for the text and `DODColor.accent` for the glyph tint per the gear-icon precedent in CL-57).
  - **Tests (commit 2):** `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests.swift` (extend — `test_shoppingListRow_unchecked`, `test_shoppingListRow_checked`, `test_shoppingListRow_longText` (Dynamic Type AX5), `test_aisleSectionHeader_produce`, `test_aisleSectionHeader_other` in light + dark; `record: .missing` lays the PNGs down on first iOS-sim run under `__Snapshots__/SnapshotTests/`).
- **AC:** Implements AC-39.4 (aisle headers in the rendered list — the visual identity), AC-39.5 (per-row toggle visual treatment — circle / checkmark.circle.fill + strikethrough). Pins CC-1 (Dynamic Type up to AX5 — the AX5 baseline locks the contract), CC-9 (visual density — the row is part of the AC-39.4 list shape, not the AC-1.3 list shape; doesn't apply directly but the row's height respects the same DODSpacing tokens).
- **Deps:** T-681 (the `Aisle` enum lives in `DODDomain` and the components take `aisle: Aisle` parameters).
- **Est:** 2h (two SwiftUI components + 5 snapshot tests).
- **||:** P12-shopping (independent of T-682 / T-684 / T-685 source-wise — T-683 owns `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/ShoppingListRow.swift` + `AisleSectionHeader.swift` exclusively; the L4 baselines are independent files).

### T-684 — `ShoppingListView` + `ShoppingListViewModel` in a new `DODFeatureShoppingList` package (US-39 / AC-39.1 + AC-39.4 + AC-39.5 + AC-39.6 + AC-39.8 + AC-39.9 + AC-39.11)
- **Scope:** Create a new `DODFeatureShoppingList` Swift package per CL-73's package-placement decision. The package depends on `DODDomain` + `DODSupport` + `DODDesignSystem` + `DODPersistence` + `DODAnalytics`. Adds `ShoppingListView` (the screen — `@Query`s `ShoppingListItem` rows from SwiftData, groups by aisle via the `ShoppingListGrouping` helper, renders each aisle as a `Section` containing `ShoppingListRow` instances with `AisleSectionHeader` per AC-39.4, surfaces the empty state per AC-39.1, hosts the Clear-all + Share toolbar buttons per AC-39.6 + AC-39.7) and `ShoppingListViewModel` (the `@Observable` view model — exposes `addItems(from recipe: Recipe)` for the AC-39.2 insertion path, `addItemsFromMany(_ recipes:)` for AC-39.3, `toggleChecked(_ item: ShoppingListItem)` for AC-39.5, `clearAll()` for AC-39.6, `shareText() -> String` for AC-39.7 via the `ShoppingListFormatter` helper). The iPad sidebar entry per AC-39.9 is wired here in the package but consumed by the Saved tab's `SavedView` per T-685 (which adds the sidebar `Label` and the toolbar button on iPhone).
- **Files:**
  - **Source (commit 1):** `Packages/DODFeatureShoppingList/Package.swift` (new — package manifest declaring the dep chain to DODDomain / DODSupport / DODDesignSystem / DODPersistence / DODAnalytics). `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListView.swift` (new — the screen). `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListViewModel.swift` (new — the view model). `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListGrouping.swift` (new — pure function `func groupByAisle(_ items: [ShoppingListItem]) -> [(Aisle, [ShoppingListItem])]` that returns the AC-39.4 store-walk order + sorts within each aisle by `addedAt` descending; pure for L1 testability). `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListFormatter.swift` (new — pure function `static func shareText(_ items: [ShoppingListItem], at date: Date) -> String` that produces the AC-39.7 plain-text payload; pure for L1 testability).
  - **Project wiring:** `project.yml` (add the `DODFeatureShoppingList` package as a local dependency of `DODFeatureSaved` + `DODFeatureRecipeDetail` per CL-73).
  - **Tests (commit 2):** `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShoppingListViewModelTests.swift` (new — L1: `addItemsFromRecipeAppendsOneRowPerIngredient`, `addItemsFromMultipleRecipesAppendsEachRecipeSeparately`, `toggleCheckedFlipsTheRowAndPersists`, `clearAllDeletesEveryRow`, `viewModelMakesZeroNetworkCalls` per REG-23). `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShoppingListGroupingTests.swift` (new — L1: `groupsByAisleInStoreWalkOrder`, `omitsEmptyAisleBuckets`, `sortsWithinAisleByAddedAtDescending`, `unknownAisleRawValueFallsBackToOther`). `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShoppingListFormatterTests.swift` (new — L1: `shareTextHasHeaderWithDate`, `shareTextOmitsEmptyAisles`, `shareTextIncludesCheckedRowsPerCL71`, `shareTextEscapesNothing` — the format is plain text, no markdown / HTML escapes needed). `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShoppingListViewSnapshotTests.swift` (new L4 — empty state + populated state (3 aisles, ~7 rows) + populated-with-checked-rows (mixed strikethrough), each in light + dark on iPhone 13 baseline at default Dynamic Type).
- **AC:** Implements AC-39.1, AC-39.4, AC-39.5, AC-39.6, AC-39.8, AC-39.9 (iPhone push surface — the iPad sidebar consumer is T-685's responsibility), AC-39.11 (VoiceOver labels — the row's accessibility composition lives in `ShoppingListRow` per T-683, but the screen-level accessibility identifiers `shopping-list-row-toggle`, `shopping-list-toolbar-clear-all`, `shopping-list-toolbar-share` come from this view).
- **Deps:** T-682 (the `ShoppingListItem` `@Model` this view queries against) + T-683 (the row + section-header primitives this view composes) + T-681 (the `Aisle` enum + classifier) + T-680 (spec entries).
- **Est:** 4h (the largest sub-task — new package + view + view-model + two helpers + ~12 L1 tests + 6 L4 snapshot baselines).
- **||:** P12-shopping (this task is the package owner; everything else depends on the package surface area existing).

### T-685 — Entry surfaces: Saved tab toolbar + per-recipe long-press menu + RecipeDetail nav-bar action (CL-73, US-39 / AC-39.2 + AC-39.3 + AC-39.9)
- **Scope:** Add the three entry surfaces per CL-73: (1) the `cart` toolbar button on `SavedView`'s nav bar (leading edge) that pushes `ShoppingListView` on iPhone or selects the sidebar row on iPad, (2) the `cart` sidebar row above the saved-recipes list on iPad per AC-39.9, (3) the `cart.badge.plus` toolbar button on `SavedView` that enters the bulk-select mode per AC-39.3 (with the per-card checkbox UI and the confirm button), (4) the `cart.badge.plus` long-press menu item on Saved-tab cards per AC-39.3 (additive to the existing US-34 / AC-34.1 "Save" menu), (5) the `cart.badge.plus` nav-bar action on `RecipeDetailView` per AC-39.2 (between Save and Download). Each entry surface invokes the same `ShoppingListViewModel.addItems(from:)` or `addItemsFromMany(_:)` from T-684.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift` (extend — add the `cart` leading-toolbar button on iPhone; on iPad, add the `Label("Shopping list", systemImage: "cart")` sidebar row at the top of the saved-recipes list and wire it into the `NavigationSplitView`'s content-column destination per AC-39.9; add the `cart.badge.plus` trailing-toolbar button that toggles bulk-select mode + the per-card checkbox overlay + the "Add N recipes →" confirm button).
    - `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedViewModel.swift` (extend — add `var isInBulkAddMode: Bool`, `var bulkSelectedRecipeIDs: Set<Int>`, `func toggleBulkSelection(_ recipeID: Int)`, `func confirmBulkAdd()` methods).
    - `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedDependencies.swift` (extend — add a `shoppingListViewModelFactory: () -> ShoppingListViewModel` injection point so the Saved view-model can hand the confirmed multi-recipe array to the shopping-list view-model without a direct dependency).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` (extend — add the `cart.badge.plus` `ToolbarItem` between Save (AC-4.7) and Download (AC-35.1); the button is disabled when `recipe.ingredients.isEmpty` and hidden entirely when `recipe.kind == .article`).
    - `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailDependencies.swift` (extend — add an `addToShoppingList: (Recipe) async -> Int` closure to the protocol surface returning the count of rows inserted; the live wiring routes to `ShoppingListViewModel.addItems(from:)`).
    - `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift` (extend — the existing `.contextMenu` modifier per AC-34.1 conditionally adds a second `Button("Add to shopping list", systemImage: "cart.badge.plus")` item when called from a Saved-tab context; the existing per-call-site placement decision per CL-60 means the menu's content is parameterized at the call site, not baked into the card).
  - **Tests (commit 2):** `Packages/DODFeatureSaved/Tests/DODFeatureSavedTests/SavedViewModelBulkAddTests.swift` (new — L1: `toggleBulkSelectionTracksRecipeID`, `confirmBulkAddRoutesEverySelectedRecipeToShoppingList`, `confirmBulkAddExitsBulkMode`). `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/RecipeDetailAddToShoppingListTests.swift` (new — L1: `addToShoppingListInvokesDependencyClosure`, `addToShoppingListSnackbarShowsItemCount`, `addToShoppingListButtonDisabledWhenIngredientsEmpty`, `addToShoppingListButtonHiddenWhenArticle`). Re-record affected L4 baselines: `SavedViewSnapshotTests` (toolbar gains two new buttons), `RecipeDetailViewSnapshotTests` (toolbar gains the cart action).
- **AC:** Implements AC-39.2 (RecipeDetail entry), AC-39.3 (Saved-tab bulk + long-press), AC-39.9 (iPad sidebar entry). Pins AC-34.1 (the existing card long-press menu is preserved + extended), AC-4.7 / AC-5.1 (Save flow unchanged), AC-35.1 (Download flow unchanged), AC-4.8 (Share flow unchanged), US-37 / AC-37.3 (the cart action is hidden on `ArticleDetailView` — articles have no ingredients).
- **Deps:** T-684 (the view model the entry surfaces invoke) + T-680 (spec entries).
- **Est:** 3h (five surface edits, two new view-model methods, ~7 L1 tests, 4 re-recorded L4 baselines).
- **||:** P12-shopping (independent of T-686 / T-687 source-wise — T-685 owns the Saved + RecipeDetail surface code; T-686 owns the share path which lives inside T-684's view-model anyway; T-687 owns analytics which is its own file family).

### T-686 — Share via `UIActivityViewController` plain text (CL-72, US-39 / AC-39.7)
- **Scope:** Wire the `UIActivityViewController` share path per AC-39.7. The `ShoppingListView`'s "Share" toolbar button (already declared in T-684's view) invokes a `ShareSheet` SwiftUI wrapper around `UIViewControllerRepresentable` for `UIActivityViewController`. The wrapper accepts a single `[Any]` array containing the plain-text payload produced by `ShoppingListFormatter.shareText(_:at:)` (which lands in T-684; this task adds the presenter and the analytics-fire integration).
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShareSheet.swift` (new — the `UIViewControllerRepresentable` wrapper that exposes `UIActivityViewController` to SwiftUI; takes `items: [Any]` + `onPresent: () -> Void` parameters; calls `onPresent` from `makeUIViewController(context:)` so the analytics event fires when the sheet appears, per CL-75's "count at present-time, not at target-tap-time" decision).
    - `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListView.swift` (extend — the existing Share toolbar button presents `ShareSheet(items: [viewModel.shareText()], onPresent: { viewModel.recordShare() })` via the standard SwiftUI `.sheet(isPresented:)` pattern).
    - `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListViewModel.swift` (extend — add `func recordShare()` that emits the `shoppingListShared(itemCount:)` telemetry event per CL-75; the actual analytics dispatch lands in T-687 but the seam is wired here so T-687's job is bounded to constants + tests).
  - **Tests (commit 2):** `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShareSheetTests.swift` (new — L1: `shareSheetWrapsActivityControllerWithPlainTextItems` — instantiates the representable with a known payload, asserts the underlying `UIActivityViewController.activityItems` matches; `shareSheetFiresOnPresentExactlyOnce` — asserts the `onPresent` closure fires once per presentation, not once per target tap). Re-record `ShoppingListViewSnapshotTests` to capture the post-presentation state if the snapshot framework's keyboard-friendly fixture allows it (otherwise no new baselines — the activity controller is a system overlay outside the snapshot host, same as the AC-34.1 context menu).
- **AC:** Implements AC-39.7 (share path), AC-39.10 (the share-side telemetry seam — `recordShare()` is the call site for the `shoppingListShared(itemCount:)` event T-687 implements).
- **Deps:** T-684 (the view + view-model the share button lives on) + T-680.
- **Est:** 1.5h (small wrapper + view-model method + 2 L1 tests).
- **||:** P12-shopping (independent of T-685 / T-687 / T-688 source-wise — T-686 owns `ShareSheet.swift` exclusively).

### T-687 — Analytics: `shoppingListItemAdded` + `shoppingListShared` events + constitution §9 amendment (CL-75, US-39 / AC-39.10)
- **Scope:** Add the two new analytics events per CL-75. Extend `AnalyticsEvent` (the existing event enum in `DODAnalytics`) with two new cases: `.shoppingListItemAdded(recipeID: Int, aisle: String)` and `.shoppingListShared(itemCount: Int)`. Wire the dispatch points: (1) `ShoppingListViewModel.addItems(from:)` fires `shoppingListItemAdded` once per inserted row (with the recipe ID + the row's `aisleRaw` string), (2) `ShoppingListViewModel.recordShare()` from T-686 fires `shoppingListShared(itemCount: items.count)`. Amend constitution §9 to add the two event names to the explicit allowlist. The App Privacy questionnaire mapping table is unchanged per CL-75 (both events fall under the existing "Usage Data — Product Interaction" row).
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift` (extend — two new enum cases + the corresponding `name` + `parameters` extension entries per the existing event pattern).
    - `Packages/DODFeatureShoppingList/Sources/DODFeatureShoppingList/ShoppingListViewModel.swift` (extend — call `Telemetry.send(.shoppingListItemAdded(recipeID: ..., aisle: ...))` inside the per-row insert loop in `addItems(from:)` and `addItemsFromMany(_:)`; call `Telemetry.send(.shoppingListShared(itemCount: ...))` from the `recordShare()` method T-686 stubbed).
    - `specs/constitution.md` (§9 amendment — append the two event names to the existing "Events tracked are limited to:" sentence with the 2026-05-27 / T-687 dating, matching the prior amendment-history pattern in §9 like `widgetOpened`).
  - **Tests (commit 2):**
    - `Packages/DODAnalytics/Tests/DODAnalyticsTests/AnalyticsEventTests.swift` (extend — `shoppingListItemAdded_emitsExpectedNameAndParameters`, `shoppingListShared_emitsExpectedNameAndParameters`).
    - `Packages/DODFeatureShoppingList/Tests/DODFeatureShoppingListTests/ShoppingListViewModelAnalyticsTests.swift` (new — L1 using `RecordingTelemetryTransport`: `addItemsFromRecipeFiresOnePerIngredientWithCorrectPayload` — asserts the recorded events match the inserted rows in count + payload; `recordShareFiresOncePerPresentationWithCorrectCount`; `noEventsFireWhenTelemetryOptOutIsOn` per AC-36.6 — the gate happens in `TelemetryDeckTransport`, not the facade, so the recording fixture stays unaffected and this assertion lives in `TelemetryDeckTransportTests` instead — note in comment for the future contributor).
- **AC:** Implements AC-39.10 (two events with the aisle-only payload). Pins AC-36.5 / AC-36.6 (the T-630 opt-out toggle gates both new events the same way), CC-5 (analytics scope — the constitution §9 amendment is the canonical way to add new events; no event lands outside the allowlist).
- **Deps:** T-684 (the view-model dispatch sites) + T-686 (the `recordShare()` seam) + T-680.
- **Est:** 1.5h (two enum cases + two dispatch sites + the §9 amendment + 4 L1 tests).
- **||:** P12-shopping (the constitution §9 amendment is the only file outside the `Packages/**` family this task touches; T-687 owns the §9 amendment exclusively in the round-8 parallels — T-670 / T-690 don't touch §9).

### T-688 — L3 smoke test: shopping-list golden path (US-39 / AC-T2 extension)
- **Scope:** Extend `DODAppUITests/SmokeTests.swift` with one new L3 smoke method `test_shoppingListGoldenPath_addOneRecipeAndSeeRowsGrouped` that exercises the canonical happy path: launch app, tap Saved tab, tap the leading-edge `cart` toolbar button, assert the empty-state copy is visible, navigate back to Saved, tap a fixture saved recipe (the test relies on the existing `DOD_E2E_MODE` plumbing per CL-58 T-602 if available, otherwise the live blog with a known recipe ID), tap the `cart.badge.plus` toolbar action on the recipe detail, return to the shopping-list screen via the Saved tab, assert at least one aisle section header is visible. This is a smoke test (per AC-T2), not an L5 user journey (per AC-T5) — it pins the "feature reachable + minimal happy-path render" contract without claiming behavioral end-state coverage.
- **Files:**
  - **Tests (single commit):** `UITests/Sources/SmokeTests.swift` (extend — one new `func` per the test name above). No source-side edits (the test relies on the surface area T-684 / T-685 / T-686 land).
- **AC:** Pins AC-T2 (L3 smoke covers app launch + tab reachability + content render). Pins AC-39.1 (empty state visible), AC-39.2 (add-from-recipe surfaces), AC-39.4 (aisle grouping renders).
- **Deps:** T-684 (the view) + T-685 (the entry surfaces) + T-686 (the share path — not exercised by this smoke but the view must compile with the share button present) + T-687 (the analytics — the smoke test doesn't assert telemetry but the dispatch sites must exist).
- **Est:** 1h (one test method; the affordance discovery via accessibility identifiers is the main work).
- **||:** P12-shopping (independent of every other T-68N source-wise — T-688 owns `UITests/Sources/SmokeTests.swift`'s new method exclusively).

### T-689 — L5 E2E user journey: build + share a shopping list (US-39 / AC-T5 extension, gated by `e2e` label)
- **Scope:** Extend `UITests/E2E/E2EJourneys.swift` (the L5 scheme target landed by T-603 per CL-58) with one new behavioral journey `test_shoppingListBuildAndShareJourney` that exercises a multi-screen workflow: launch via `DOD_E2E_MODE=1` (per CL-58's launch-argument convention), tap Saved tab, save two fixture recipes, return to Saved, tap the `cart.badge.plus` toolbar action to enter bulk mode, select both recipes, tap "Add 2 recipes →", verify the shopping-list screen renders both recipes' ingredients grouped by aisle, tap the toggle on one row, verify the strikethrough renders, tap "Share" and assert the `UIActivityViewController` presents (the test asserts the presentation via the `XCUIApplication.activityListView` query; it does NOT actually share — that'd require granting Messages permission in the test simulator). This is the meaningful end-to-end behavioral coverage per AC-T5; the journey takes the user through "save → bulk-add → render → toggle → share" without overlapping the L3 smoke's surface scope.
- **Files:**
  - **Tests (single commit):** `UITests/E2E/E2EJourneys.swift` (extend — one new `func` per the journey name above). No source-side edits.
  - **CI workflow:** none (the existing `test-e2e` job in `.github/workflows/ci.yml` per CL-58 / T-604 picks up the new test method automatically; the workflow's path-filter + label-conditional logic doesn't need an update for an additive test method).
- **AC:** Pins AC-T5 (L5 user journeys), AC-39.2 (single-recipe add), AC-39.3 (multi-recipe bulk add), AC-39.4 (aisle grouping), AC-39.5 (toggle), AC-39.7 (share presentation). Locks `REG-23` (the L1 + L2 contract for "no network egress" is preserved by this journey since it runs entirely in-process against `DOD_E2E_MODE=1` fixtures).
- **Deps:** T-684 + T-685 + T-686 + T-687 (the full feature surface) + T-680. CI environment dependency on T-602 / T-603 / T-604 (the L5 scheme + workflow infrastructure — already on `main`).
- **Est:** 1.5h (one journey method, ~30 lines of `XCUIElement` driving; the affordance discovery is the main work and parallels T-688's smoke method).
- **||:** P12-shopping (independent of every other T-68N source-wise — T-689 owns `UITests/E2E/E2EJourneys.swift`'s new method exclusively; the PR for this task carries the `e2e` label so the L5 job runs on it per CL-58's gating policy).

---

## Phase 15 — Account + Cross-device sync via CloudKit (2026-05-28)

Round-6 Spencer backlog item "Login + account system (Google + Apple + email)" graduates after the dad-led architecture conversation. **Dad picked CloudKit** as the backend strategy, dramatically simplifying what Spencer originally captured: the user's iCloud account *is* the sync identity — no OAuth providers, no password handling, no login UI at all. T-700 lands the spec amendment (US-41 + CL-86..CL-99); T-701..T-708 implement the feature across eight sub-tasks. Cluster owner: dad. Parallelism tag: `P15-cloudkit-sync`. No parallel round-9 work is currently in-flight (all round-8 parallels — T-660 / T-670 / T-680..T-680c / T-690a..T-690c — have landed), so this PR lands cleanly without spec-file collisions; T-700 reserves CL-86..CL-99 (CL-84 skipped per the prior-phase parallel renumbering), US-41, T-700..T-708.

### T-700 — Account + Cross-device sync via CloudKit spec amendment (US-41, CL-86..CL-99)
- **Scope:** Pure spec-only PR. Adds US-41 (Cross-device sync via CloudKit) with AC-41.1..AC-41.13 to `spec.md`; appends CL-86..CL-99 to `clarifications.md` under a new "Phase 15 amendments" section; adds the T-700..T-708 cluster + Summary block update to `tasks.md`; graduates the round-6 "Login + account system (Google + Apple + email)" backlog entry with strike-through + a Recently-graduated section reference in `backlog.md`. Touches `specs/constitution.md` (§1 / §3 / §4 amendments — small wording deltas that acknowledge the CloudKit posture without changing v1.0 behavior; the §9 amendment for the four new analytics events lands paired with T-707, not here, per the established "amendment with the event" convention). Updates `Marketing/AppPrivacy.md` with the App Privacy questionnaire delta (per CL-94 — no new data category to declare). No source code, no test files. REG-25 + REG-26 inserted in the AC-T4 block.
- **Files:**
  - **Spec/clarifications/tasks/backlog/constitution/marketing (single PR, multiple commits):** `specs/dod-ios-app/spec.md` (US-41 + AC-41.1..AC-41.13 inserted after US-40; REG-25 + REG-26 inserted in the AC-T4 test pyramid block; v1 scope (out) bullet for "Cross-device sync (iCloud) of saved recipes" struck through with the graduation marker; AC-5.7 amendment via strike-through + lineage marker per CL-97), `specs/dod-ios-app/clarifications.md` (CL-86..CL-99 appended under a new "Phase 15 amendments (Account + Cross-device sync via CloudKit, 2026-05-28)" section header after the Phase 14 summary; CL-5 amended with strike-through + lineage marker per CL-86 — *amendment of CL-5 is by reference; the CL-86 entry contains the full reversal trail*), `specs/dod-ios-app/tasks.md` (this Phase 15 section + Summary block update), `specs/dod-ios-app/backlog.md` (graduate the round-6 "Login + account system (Google + Apple + email)" item with strike-through + a Recently-graduated entry), `specs/constitution.md` (§1 v2-sync-model subsection added; §3 CloudKit.framework added to allow-list; §4 "Synced records" data-boundary category added; §9 left untouched here — the four-event allowlist amendment lands paired with T-707), `Marketing/AppPrivacy.md` (update — the "What changes for v2" speculation block is superseded with a corrected delta per CL-94; the new section documents the App Privacy questionnaire delta which is "no change" plus the four-event addition under the existing Usage Data row, dated for the T-707-paired §9 amendment), `Marketing/TestFlight.md` (update — add the AC-41.12 / CL-95 TestFlight gate: "Verify dutchovendaddy.com/app-privacy/ contains the CL-95 'Optional iCloud Sync' paragraph before submitting any build that enables CloudKit sync").
- **AC:** Implements no spec ACs directly; produces the spec entries that AC-41.1..AC-41.13 + REG-25 + REG-26 trace to. Pins constitution §11 ("PR cites the spec.md section(s) it implements") by being the spec.md section everything else cites. The §1 / §3 / §4 amendments are dated + cite this task so a future reader can see "this was a v1.x amendment, not a v1.0 rule" per CONTRIBUTING.md.
- **Deps:** None.
- **Est:** 0h source / 6h docs (14 CLs + 13 ACs + 2 REG bullets + 9 task entries + constitution touches across three sections + AppPrivacy delta + TestFlight gate; the writing is the work).
- **||:** P15-cloudkit-sync (this PR; T-701..T-708 are the implementation parallels per the entries below).

### T-701 — CloudKit container provisioning + entitlement wiring (CL-93, US-41 / AC-41.4 + AC-41.5)
- **Scope:** Pure deployment + entitlements PR. Adds the two new iCloud entitlement keys to `App/DODApp.entitlements` (`com.apple.developer.icloud-container-identifiers` with the value `iCloud.com.dutchovendaddy.DODApp`, and `com.apple.developer.icloud-services` with `CloudKit`). Adds the `remote-notification` UIBackgroundModes value to `App/Info.plist` (and the `project.yml` info.properties block — per the REG-INFO-PLIST-CLOBBER fix, the key must be in both files). Does NOT touch any application code. Per CL-93, this PR is deliberately sequenced before T-702 so the entitlements + container land + can be verified independently of the sync adapter wiring. **Apple Developer Portal + App Store Connect provisioning steps** are documented in `Marketing/TestFlight.md` (added by T-700): (1) Apple Developer Portal → Identifiers → App IDs → enable iCloud + CloudKit support; (2) CloudKit Dashboard → create container `iCloud.com.dutchovendaddy.DODApp` with Development + Production environments; (3) `fastlane match` regenerate to refresh the provisioning profile with the new entitlement; (4) verify the entitlements show in the Xcode "Signing & Capabilities" tab post-regenerate.
- **Files:**
  - **Entitlements + Info.plist (single commit):** `App/DODApp.entitlements` (extend — two new `<key>` + `<array>` blocks per CL-93). `App/Info.plist` (extend — `UIBackgroundModes` array gains `remote-notification`). `project.yml` (extend — `info.properties` block adds the corresponding `UIBackgroundModes` entry per REG-INFO-PLIST-CLOBBER's "keep both files in sync" rule).
  - **Provisioning notes:** `Marketing/TestFlight.md` (already updated by T-700 with the gate; T-701 adds the per-step verification checklist as a follow-up "verify-after-T-701" section).
- **AC:** Pins AC-41.4 (the synced records' CloudKit container identifier matches the entitlement value); AC-41.5 (the account-status integration depends on the entitlement being present). REG-INFO-PLIST-CLOBBER (the Info.plist edits are mirrored in `project.yml`).
- **Deps:** T-700 (the spec entries this task implements against).
- **Est:** 1h (entitlements file + Info.plist + project.yml are all small edits; the App Store Connect provisioning is documented in the task notes but happens on dad's side outside the PR).
- **||:** P15-cloudkit-sync. T-701 owns `App/DODApp.entitlements` + the `UIBackgroundModes` addition in Info.plist / project.yml exclusively. Sequenced before T-702 per CL-93's "land entitlements first" rationale.
- **Shipped:** commit `<pending>` (2026-05-28). Landed the two iCloud entitlement keys in `App/DODApp.entitlements` (`com.apple.developer.icloud-container-identifiers` = `iCloud.com.dutchovendaddy.DODApp`, `com.apple.developer.icloud-services` = `CloudKit`) and added the "Verify-after-T-701 — CloudKit container provisioning checklist" to `Marketing/TestFlight.md` as a six-step click-by-click runbook for the Apple Developer Portal + CloudKit Dashboard + Xcode signing-tab verification. **Deferred to T-702:** the `remote-notification` `UIBackgroundModes` value on `App/Info.plist` + `project.yml` (per CL-99) was scoped out of this PR so the entitlement change lands clean; T-702 picks it up alongside the SwiftData → CloudKit adapter wiring since the silent-push surface only becomes load-bearing once the adapter is observing `CKDatabaseSubscription`. **Apple Developer Portal + CloudKit Dashboard steps remain operational** — they happen on the team-owner's Apple ID (dad's), not in this PR; the six-step checklist in `Marketing/TestFlight.md` is the runbook.

### T-702 — SwiftData → CloudKit sync adapter (CL-88, US-41 / AC-41.1 + AC-41.4 + AC-41.5 + AC-41.6 + AC-41.11)
- **Scope:** Wire SwiftData → CloudKit private DB via the iOS 17+ `ModelConfiguration(_:groupContainer:cloudKitDatabase: .private(...))` initializer. Per CL-88, only `CachedRecipe` rows where `isSaved == true` mirror; the explicit exclusion list (per CL-88's enumeration) is enforced by the adapter declaring `Schema.cloudKitModels = [CachedRecipe.self]` and the per-field syncability per the AC-41.4 list. Adds one new field to `CachedRecipe`: `modifiedAt: Date?` (additive Optional column per the established R-5 rule in `MIGRATION.md`; lightweight migration, no schema bump). Adds a new `CloudKitSyncAdapter` actor in `DODPersistence` that wraps the SwiftData `ModelContainer` setup, exposes `start()` / `stop()` / `clearLocalMirror()` (the AC-41.5 path) / `forceSync()` (the AC-41.7 "tap to retry" path) methods, and observes `CKAccountStatus` via `NotificationCenter` for the `CKAccountChangedNotification` postings. The `RecipeStore` mutating write paths (`cache(listItem:)`, `mergeDetail(_:)`, `toggleSaved(id:)`, `markDownloaded(id:)`, `clearBlocklist()`) each set `modifiedAt = .now` so AC-41.8's LWW conflict resolution has a comparable timestamp. Implements REG-25 (the L1 surface-test that the adapter only accesses `privateCloudDatabase` + `accountStatus(completionHandler:)`).
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODPersistence/Sources/DODPersistence/CachedRecipe.swift` (extend — add the `modifiedAt: Date?` field with the default-nil initializer parameter; doc comment cites CL-90's LWW resolution rule).
    - `Packages/DODPersistence/Sources/DODPersistence/RecipeStore.swift` (extend — set `target.modifiedAt = .now` in every existing mutating write path, paired with each existing `try modelContext.save()` call).
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncAdapter.swift` (new — the adapter actor; ~150 LOC; the `start()` method registers the `CKAccountChanged` observer + creates the `ModelContainer` with the `.private` cloudKitDatabase parameter; `stop()` deactivates the adapter + flushes pending; `clearLocalMirror()` per AC-41.5; `forceSync()` per AC-41.7).
    - `Packages/DODPersistence/Sources/DODPersistence/RecipeStore+Containers.swift` (extend — the container-init path branches on `dod.cloudKitSyncEnabled` and either constructs the plain SwiftData container OR the CloudKit-backed one).
  - **Tests (commit 2):**
    - `Packages/DODPersistence/Tests/DODPersistenceTests/CloudKitSyncAdapterTests.swift` (new — L1: `adapterStartsAndStopsCleanly`, `accountStatusChangeTriggersSync`, `clearLocalMirrorRemovesSyncedRowsButPreservesGuestIdentity`, `forceSyncTriggersImmediateRoundTrip`; uses a `MockCKContainer` injected via the adapter's testability seam).
    - `Packages/DODPersistence/Tests/DODPersistenceTests/CloudKitContainerSurfaceTests.swift` (new — REG-25: L1 build-time + source-grep assertions that the adapter source references only `privateCloudDatabase` + `accountStatus(completionHandler:)`; the test reads the compiled binary's symbol table via `nm $(BUILT_PRODUCTS_DIR)/DODPersistence.framework/DODPersistence | grep -E 'discoverUserIdentity|publicCloudDatabase|sharedCloudDatabase|userDiscoverability'` and fails on any hit).
    - `Packages/DODPersistence/Tests/DODPersistenceTests/MigrationCloudKitFieldsTests.swift` (new — L1: assert the `modifiedAt: Date?` field round-trips through save/load; assert a row inserted pre-migration (with `modifiedAt = nil`) loads correctly post-migration).
  - **Persistence docs:** `Packages/DODPersistence/MIGRATION.md` (update — append a "Phase 15: `modifiedAt` on `CachedRecipe`" section documenting the additive optional column + the CL-90 LWW rationale).
- **AC:** Implements AC-41.1 (the no-CloudKit code path stays intact when `dod.cloudKitSyncEnabled = false`), AC-41.4 (the synced fields enumerated per CL-88), AC-41.5 (the `clearLocalMirror()` deletion path), AC-41.6 (offline behavior — SwiftData writes complete immediately; the adapter's queue + flush is asynchronous), AC-41.11 (additive migration). Locks REG-25 (CloudKit surface contract) and REG-26 partial (the no-iCloud-account fallback in `start()`).
- **Deps:** T-700 (spec entries) + T-701 (entitlements + container must exist before the adapter can construct the `ModelConfiguration` with `cloudKitDatabase:`).
- **Est:** 5h (the adapter is bounded but the cross-cutting touch points on `RecipeStore` + the surface-test suite for REG-25 are the heavy lifts).
- **||:** P15-cloudkit-sync. T-702 owns `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncAdapter.swift` + the `modifiedAt` field on `CachedRecipe` + the per-write `modifiedAt` settings in `RecipeStore` exclusively. T-706 (conflict resolution) builds on top.
- **Shipped:** commit `<pending>` (2026-05-28). Landed the SwiftData → CloudKit sync engine + SchemaV4 + the silent-push `UIBackgroundModes` declaration. **SchemaV4** ships as a real `VersionedSchema` with a `models` list byte-identical to V3's; per Apple's documented duplicate-checksum trap (the same one the T-640 article-body-HTML follow-up hit), V4 is intentionally NOT registered in `MigrationPlan.schemas` — SwiftData's same-fingerprint inference handles the V3 → V4 no-op transition transparently. The production `ModelContainer` now references `SchemaV4.models` as source of truth. **`RecipeStore.productionContainer()`** branches on `UserDefaults.standard.bool(forKey: "dod.cloudkit.syncOptInV1")` (the opt-in flag T-703 / T-704 will write); opt-in=true constructs `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.dutchovendaddy.DODApp"))` (per CL-93's container identifier), opt-in=false constructs `ModelConfiguration(cloudKitDatabase: .none)` — the explicit `.none` is load-bearing because SwiftData's default `.automatic` auto-enables CloudKit whenever the iCloud entitlement is present (T-701's), which would otherwise crash the app at container open with "CloudKit integration requires that all attributes be optional, or have a default value set" since the V3 `@Model` shapes have non-optional fields + unique constraints. Setting `.none` explicitly is the AC-41.1 graceful-fallback contract. Added `RecipeStore.recreateContainerAfterOptInChange() -> ModelContainer` as the seam T-703's Settings toggle calls when the flag flips so the host can swap the stale container. **`AppDependencies.checkCloudKitAvailability()`** added (gated on the opt-in flag) — calls `CKContainer(identifier:).accountStatus()` and logs the result via `DODLog.app`; never crashes per AC-41.1. **`UIBackgroundModes: [remote-notification]`** added to the DODApp target's `info.properties:` block in `project.yml` (regenerates into `App/Info.plist` via `xcodegen generate`) for SwiftData's default `CKDatabaseSubscription` silent-push wakeup (per CL-99). Tests: `SchemaV4Tests` (4 new tests: V3→V4 migration, fresh V4 install, opt-in OFF doesn't touch CloudKit, opt-in ON produces CloudKit configuration); updated `v3MigrationPlanLists3VersionsAnd2Stages` → `migrationPlanListsAllVersionsAndStages` (still 3 schemas / 2 stages — V4 absent from plan). `Packages/DODPersistence/MIGRATION.md` updated with the V4 entry + the duplicate-checksum trap follow-up note. App launched on iPhone 17 sim with opt-in OFF (default) and stayed alive (PID 53409 confirmed). **Deferred to T-706:** the `modifiedAt: Date?` field on `CachedRecipe` + the per-write `modifiedAt = .now` settings on the `RecipeStore` mutating paths — T-702's scope was the schema-identity + configuration boundary; T-706 (conflict resolution per CL-90) owns the LWW timestamp field + the merge policy. **Deferred to a future Apple-developer-portal step:** CloudKit container schema deployment from Development → Production (per CL-93's step 3) — operational, not blocked by this PR. **Deferred to T-703 / T-704:** the UI surface that writes the `dod.cloudkit.syncOptInV1` flag. The container factory reads the flag; today no UI writes it, so the opt-in path is dead code in production until T-703 ships.

### T-703 — Settings → iCloud Sync toggle + status surface integration (CL-89, US-41 / AC-41.3 + AC-41.5 + AC-41.7 + AC-41.10)
- **Scope:** Add a new "iCloud Sync" row to the Settings page (T-630). The row sits between the existing "Notifications" row and the "Appearance" row per the AC-41.3 ordering. The row is a SwiftUI `Toggle` bound to a `@AppStorage("dod.cloudKitSyncEnabled")` boolean (default `false`), plus a secondary status sublabel per AC-41.7. Toggling on activates the sync adapter (calls `CloudKitSyncAdapter.start()`); toggling off presents a confirmation alert per CL-92 ("This will remove your saved recipes from iCloud. Your saved recipes on this device are preserved.") with a "Turn off and remove from iCloud" primary + "Cancel" secondary; the primary calls `CloudKitSyncAdapter.clearLocalMirror()` + `stop()`. Fires `syncEnabled` / `syncDisabled` events (placeholders for T-707 to implement; the dispatch seam is wired here). The status sublabel pulls state from a new `CloudKitSyncStatus` observable that the adapter exposes per AC-41.7's five-state taxonomy. Accessibility per AC-41.10.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureSettings/Sources/DODFeatureSettings/SettingsView.swift` (extend — add the iCloud Sync row between Notifications and Appearance; the row composes a `Toggle` with `accessibilityIdentifier("settings-icloud-sync-toggle")` + an `accessibilityLabel("iCloud Sync")` + an action-hint that flips on state; the status sublabel renders the `CloudKitSyncStatus`'s `displayString`).
    - `Packages/DODFeatureSettings/Sources/DODFeatureSettings/SettingsViewModel.swift` (extend — hold the `@AppStorage("dod.cloudKitSyncEnabled")` binding + the confirmation alert state; methods `toggleCloudKitSync()`, `confirmTurnOff()`, `cancelTurnOff()`).
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncStatus.swift` (new — the `@Observable` status enum with cases per AC-41.7: `.disabled`, `.idle(lastSynced: Date?)`, `.pausedNoNetwork`, `.pausedNoAccount`, `.pausedAfterRetries`, `.error`; the `displayString` computed property formats per AC-41.7's coarse-grained "N ago" rule).
    - `Packages/DODFeatureSettings/Sources/DODFeatureSettings/SettingsDependencies.swift` (extend — inject the `CloudKitSyncAdapter` for the toggle action wiring).
  - **Tests (commit 2):**
    - `Packages/DODFeatureSettings/Tests/DODFeatureSettingsTests/SettingsCloudKitToggleTests.swift` (new — L1: `togglingOnActivatesAdapter`, `togglingOffPresentsConfirmationAlert`, `confirmTurnOffCallsClearLocalMirror`, `cancelTurnOffLeavesToggleOn`, `statusSublabelReflectsAdapterState`).
    - `Packages/DODFeatureSettings/Tests/DODFeatureSettingsTests/SettingsRowReachableWhenNotSignedInTests.swift` (new — REG-26 partial: assert the row renders without crash when `CKAccountStatus == .noAccount`, the sublabel reads "Sign into iCloud to enable sync", tapping the row routes to the system Settings URL).
    - L4 snapshot baselines: `SettingsViewSnapshotTests` (extend — re-record the Settings page baselines with the new row in toggle-off, toggle-on-syncing, toggle-on-paused-no-network states; light + dark + AX5 per CC-1).
- **AC:** Implements AC-41.3 (the toggle + the confirmation alert flow), AC-41.5 partial (the toggle-off path triggers `clearLocalMirror()`), AC-41.7 (the status sublabel), AC-41.10 (VoiceOver + AX5 accessibility). Locks REG-26 partial (the no-iCloud-account row state).
- **Deps:** T-702 (the `CloudKitSyncAdapter` the toggle calls + the `CloudKitSyncStatus` the sublabel reads).
- **Est:** 3h (one new row + view-model state + confirmation alert + status sublabel + snapshot baselines).
- **||:** P15-cloudkit-sync. T-703 owns the new iCloud Sync row in `SettingsView.swift` + `SettingsViewModel.swift` exclusively.

### T-704 — First-launch opt-in prompt (CL-89, US-41 / AC-41.2 + AC-41.10)
- **Scope:** Implement the AC-41.2 opt-in sheet — a single-screen modal SwiftUI sheet presented on the first cold launch after the user upgrades to the version with CloudKit sync, gated by the `@AppStorage("dod.cloudKitSyncOptInPromptShownV1")` flag. The sheet contains a headline ("Sync your saved recipes across devices"), one sentence of body copy, a primary button ("Turn on iCloud Sync") + a secondary button ("Not now"), and accessibility per AC-41.10. Tapping primary sets `dod.cloudKitSyncEnabled = true` + flips the prompt-shown flag + dismisses + triggers `CloudKitSyncAdapter.start()`. Tapping secondary or dismissing flips the prompt-shown flag only. The sheet is presented from the root view (`RootView` — the same surface that hosts the AC-8.1 onboarding sheet, mirroring the design language). The post-prompt iCloud-sign-in re-activation listener per CL-89 lives in `AppDependencies` (it observes `CKAccountChangedNotification` and activates the adapter when both flags are true).
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODFeatureOnboarding/Sources/DODFeatureOnboarding/CloudKitOptInSheet.swift` (new — the sheet view; ~80 LOC; matches the AC-8.1 sheet's visual + spacing language; uses the existing `DODType` + `DODColor` + `DODSpacing` tokens).
    - `App/RootView.swift` (extend — add the `.sheet(isPresented: $shouldShowCloudKitOptInSheet)` modifier that surfaces the sheet on first launch post-upgrade; the binding is driven by an `@AppStorage("dod.cloudKitSyncOptInPromptShownV1")` flag inverted).
    - `App/AppDependencies.swift` (extend — register the `CKAccountChangedNotification` observer that activates `CloudKitSyncAdapter` when both `dod.cloudKitSyncOptInPromptShownV1 == true` and `dod.cloudKitSyncEnabled == true` and `CKAccountStatus == .available`).
  - **Tests (commit 2):**
    - `Packages/DODFeatureOnboarding/Tests/DODFeatureOnboardingTests/CloudKitOptInSheetTests.swift` (new — L1: `primaryButtonTapSetsEnabledFlagAndDismisses`, `secondaryButtonTapSetsPromptShownFlagOnly`, `swipeToDismissActsLikeSecondaryTap`, `sheetShowsOnlyWhenPromptShownFlagIsFalse`).
    - `Packages/DODFeatureOnboarding/Tests/DODFeatureOnboardingTests/CloudKitOptInSheetSnapshotTests.swift` (new — L4: snapshot the sheet in light + dark + default Dynamic Type + AX5 per CC-1; `record: .missing`).
- **AC:** Implements AC-41.2 (the opt-in sheet surface + the never-re-prompt contract), AC-41.10 partial (the sheet's VoiceOver + AX5 accessibility).
- **Deps:** T-702 (the `CloudKitSyncAdapter.start()` the primary button calls) + T-703 (the `@AppStorage("dod.cloudKitSyncEnabled")` flag the sheet writes).
- **Est:** 2h (one new sheet view + root view integration + L1/L4 tests).
- **||:** P15-cloudkit-sync. T-704 owns `CloudKitOptInSheet.swift` + the `.sheet` modifier in `RootView` + the `CKAccountChanged` observer in `AppDependencies` exclusively.

### T-705 — Offline queue + retry + Settings status surface (CL-91, US-41 / AC-41.6 + AC-41.7)
- **Scope:** Wire the offline-queue + retry + status-surface plumbing per CL-91. SwiftData's CloudKit adapter handles the queue + flush internally; T-705 adds the observation surface that exposes sync state to the Settings sublabel (T-703 already declares the `CloudKitSyncStatus` enum; T-705 implements the state-machine transitions inside `CloudKitSyncAdapter`). The retry budget per AC-41.6 (3 consecutive failures → "Sync paused — tap to retry") is implemented as an explicit counter in the adapter; `forceSync()` (per AC-41.7's tap-to-retry path) resets the counter + re-fires the pending queue. The status sublabel's text generation (the AC-41.7 coarse-grained "N ago" formatting) lives in `CloudKitSyncStatus.displayString` (per T-703).
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncAdapter.swift` (extend — add the `@Observable` `status: CloudKitSyncStatus` property; implement state transitions on the adapter's existing `start()` / `stop()` / observed-CK-events paths; implement the 3-consecutive-failures → `.pausedAfterRetries` transition + the `forceSync()` retry reset).
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncStatus.swift` (extend — flesh out the `displayString` computed property per the AC-41.7 coarse-grained format ("just now" / "M minutes ago" / "H hours ago" / "D days ago") + the localization-aware time-ago formatter).
  - **Tests (commit 2):**
    - `Packages/DODPersistence/Tests/DODPersistenceTests/CloudKitSyncStatusTests.swift` (new — L1: `displayString_justNow`, `displayString_minutesAgo`, `displayString_hoursAgo`, `displayString_daysAgo`, `status_transitionsOnSuccess`, `status_transitionsOnFailure`, `status_threeFailuresEntersPausedAfterRetries`, `forceSync_resetsRetryCounter`).
- **AC:** Implements AC-41.6 (the offline-write completes-immediately contract + the retry budget) + AC-41.7 (the status sublabel state-machine + display strings).
- **Deps:** T-702 (the adapter) + T-703 (the `CloudKitSyncStatus` enum).
- **Est:** 2.5h (state machine + the time-ago formatting + L1 coverage).
- **||:** P15-cloudkit-sync. T-705 extends `CloudKitSyncAdapter` + `CloudKitSyncStatus` only.

### T-706 — Conflict resolution: LWW for mutable fields, max-value for idempotents (CL-90, US-41 / AC-41.8)
- **Scope:** Implement the AC-41.8 LWW conflict-resolution path for cross-device record merges. SwiftData's CloudKit adapter exposes a `mergePolicy` hook that the adapter overrides with a custom `LastWriteWinsMergePolicy` per the CL-90 sub-table. The policy reads the local + remote `modifiedAt` fields (T-702 added) and applies LWW for mutable fields, OR for `isSaved`, max-value for `lastViewedAt` / `downloadedAt`. Adds a `RecipeStore.applyCloudKitMerge(_ localRow:, _ remoteRow:)` method that the policy invokes; the per-field merge logic is data-driven via the CL-90 sub-table encoded as a static dictionary.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODPersistence/Sources/DODPersistence/LastWriteWinsMergePolicy.swift` (new — the merge-policy implementation; ~120 LOC; the per-field merge rule dictionary; the `merge(local:, remote:)` method returns the resolved `CachedRecipe` state).
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncAdapter.swift` (extend — register the merge policy with the SwiftData ModelContainer setup).
  - **Tests (commit 2):**
    - `Packages/DODPersistence/Tests/DODPersistenceTests/MergeResolutionTests.swift` (new — L1: `lww_titleResolvesByModifiedAt`, `or_isSavedTrueOnEitherSide`, `or_isSavedFalseOnlyIfBothFalseAndModifiedAtMatches`, `maxValue_lastViewedAt`, `maxValue_downloadedAt_nilLosesToValue`, `lww_jsonBlobsRespectModifiedAt`, `clockSkewWithinOneSecondResolvesByModifiedAtAnyway`, `nilModifiedAtIsTreatedAsDistantPast`).
- **AC:** Implements AC-41.8 (the LWW + per-field-rule resolution).
- **Deps:** T-702 (the `modifiedAt` field + the adapter the policy registers with).
- **Est:** 3h (the per-field merge rule + comprehensive L1 coverage).
- **||:** P15-cloudkit-sync. T-706 owns `LastWriteWinsMergePolicy.swift` exclusively.

### T-707 — Analytics: four new sync events + constitution §9 amendment (CL-96, US-41 / AC-41.9)
- **Scope:** Add the four new analytics events per AC-41.9 + CL-96. Extend `AnalyticsEvent` (the existing event enum in `DODAnalytics`) with four new cases: `.syncEnabled`, `.syncDisabled`, `.syncCompletedSuccessfully`, `.syncFailed(errorCategory: SyncErrorCategory)`. Add the `SyncErrorCategory` closed enum (`network` / `accountStatus` / `quotaExceeded` / `serverInternal` / `other`) per CL-96. Wire the dispatch points: (1) `SettingsViewModel.toggleCloudKitSync()` fires `syncEnabled` / `syncDisabled`, (2) the AC-41.2 opt-in primary button fires `syncEnabled`, (3) `CloudKitSyncAdapter` fires `syncCompletedSuccessfully` (debounced to 60s per CL-96) on successful round-trips and `syncFailed(errorCategory:)` on retry-budget exhaustion. Amend constitution §9 to add the four event names to the explicit allowlist with the closed-enum-payload posture documentation. The App Privacy questionnaire mapping table is unchanged per CL-94.
- **Files:**
  - **Source (commit 1):**
    - `Packages/DODAnalytics/Sources/DODAnalytics/AnalyticsEvent.swift` (extend — four new enum cases + `name` + `parameters` extension entries per the existing event pattern).
    - `Packages/DODAnalytics/Sources/DODAnalytics/SyncErrorCategory.swift` (new — the closed enum + the `CKError.Code → SyncErrorCategory` mapping function for the adapter's dispatch site).
    - `Packages/DODPersistence/Sources/DODPersistence/CloudKitSyncAdapter.swift` (extend — call `Telemetry.send(.syncCompletedSuccessfully)` per the 60s debounce; call `Telemetry.send(.syncFailed(errorCategory: ...))` on retry-budget exhaustion).
    - `Packages/DODFeatureSettings/Sources/DODFeatureSettings/SettingsViewModel.swift` (extend — call `Telemetry.send(.syncEnabled)` / `Telemetry.send(.syncDisabled)` in the toggle path).
    - `Packages/DODFeatureOnboarding/Sources/DODFeatureOnboarding/CloudKitOptInSheet.swift` (extend — call `Telemetry.send(.syncEnabled)` on primary tap).
    - `specs/constitution.md` (§9 amendment — append the four event names + the closed-enum-posture documentation to the existing "Events tracked are limited to:" sentence with the 2026-05-28 / T-707 dating, matching the prior `widgetOpened` / `voiceModeToggled` / `voiceCommandFired` amendment-history pattern).
  - **Tests (commit 2):**
    - `Packages/DODAnalytics/Tests/DODAnalyticsTests/AnalyticsEventTests.swift` (extend — `syncEnabled_emitsExpectedName`, `syncDisabled_emitsExpectedName`, `syncCompletedSuccessfully_emitsExpectedName`, `syncFailed_emitsExpectedNameAndCategoryString`, `syncFailed_categoryEnumIsClosedSet`).
    - `Packages/DODPersistence/Tests/DODPersistenceTests/CloudKitSyncAdapterAnalyticsTests.swift` (new — L1 using `RecordingTelemetryTransport`: `successfulRoundTripFiresSyncCompletedSuccessfullyOnce`, `secondSuccessWithin60sIsDebounced`, `retryBudgetExhaustionFiresSyncFailed`, `errorCategoryMappingFromCKErrorCode`).
- **AC:** Implements AC-41.9 (the four events + the closed-enum payload posture). Pins AC-36.5 / AC-36.6 (the T-630 opt-out toggle gates these events the same way as every other event), CC-5 (analytics scope — the constitution §9 amendment is the canonical way to add new events; no event lands outside the allowlist).
- **Deps:** T-702 (the adapter dispatch sites) + T-703 (the Settings toggle dispatch sites) + T-704 (the opt-in sheet dispatch site).
- **Est:** 2.5h (four enum cases + four dispatch sites + the §9 amendment + 9 L1 tests).
- **||:** P15-cloudkit-sync. T-707 owns the §9 amendment exclusively in this cluster; no parallel work touches §9.

### T-708 — L1 + L3 + L5 tests: E2E journey, smoke under no-iCloud, REG-26 (US-41 / AC-T2 + AC-T5 extension + REG-26)
- **Scope:** The test-coverage closure for US-41. Three layers: (1) **L1 expansion** — extend the `RecordingURLProtocol` fixture used in the existing REG-23 ShoppingList tests to also assert "no `iCloud.com.dutchovendaddy.DODApp` container API calls occur when sync is disabled" — locks the AC-41.1 "app works without iCloud sign-in" contract from the network egress side. (2) **L3 smoke addition** — `SmokeTests.test_appLaunchesUnderNoiCloudAccount` per REG-26 — launches the app with `XCUIApplication.launchArguments += ["-DOD_CLOUDKIT_FAKE_ACCOUNT_STATUS=noAccount"]`, verifies the existing smoke path (launch + tab reachability + recipe detail open + save toggle visible per AC-T2) passes identically to the standard baseline. The fake-account-status launch arg lands as part of T-708's host-side scope (a small extension to `App/AppDependencies.swift`'s test-launch-overrides path). (3) **L5 E2E user journey** — `E2EJourneys.test_cloudKitSyncEnableSaveVerifyDisableCleared` exercises the full end-to-end behavioral contract: launch via `DOD_E2E_MODE=1` + `DOD_CLOUDKIT_FAKE_ACCOUNT_STATUS=available`, dismiss-or-accept the AC-41.2 opt-in sheet, save a fixture recipe, verify `MockCKContainer` recorded an upload, disable sync via Settings, confirm the alert, verify `MockCKContainer.records` is empty (the AC-41.5 deletion path round-tripped). Plus `E2EJourneys.test_fullGoldenPathUnderNoiCloudAccount` per REG-26 (same launch arg as the L3 smoke, but exercises the open → tap → save → unsave journey end-to-end).
- **Files:**
  - **Source (commit 1):**
    - `App/AppDependencies.swift` (extend — add the `DOD_CLOUDKIT_FAKE_ACCOUNT_STATUS` launch-arg parsing + the `MockCKContainer` swap when the flag is set).
    - `Packages/DODPersistence/Sources/DODPersistence/MockCKContainer.swift` (new — the test-friendly fake; conforms to a `CloudKitContainerProtocol` seam the adapter uses; records uploads + deletes so tests can assert).
  - **Tests (commit 2):**
    - `Packages/DODPersistence/Tests/DODPersistenceTests/CloudKitNoAccountTests.swift` (new — REG-26 L1 partial: assert `CloudKitSyncAdapter.start()` under `.noAccount` enters the `.pausedNoAccount` state without crash, no upload attempts are made).
    - `UITests/Sources/SmokeTests.swift` (extend — `test_appLaunchesUnderNoiCloudAccount` per REG-26 L3).
    - `UITests/E2E/E2EJourneys.swift` (extend — `test_cloudKitSyncEnableSaveVerifyDisableCleared` + `test_fullGoldenPathUnderNoiCloudAccount` per AC-T5 + REG-26 L5).
- **AC:** Pins AC-T2 (L3 smoke covers the no-iCloud-account path), AC-T5 (L5 user journey for sync enable/disable round-trip), REG-26 (the full "app works without iCloud sign-in" contract — locked at L1, L3, L5).
- **Deps:** T-702 (the adapter + the seam the mock conforms to) + T-703 (the Settings toggle the journey drives) + T-704 (the opt-in sheet the journey navigates) + T-707 (the analytics events the journey can observe via the recording transport, though the journey doesn't assert on them specifically). CI environment dependency on T-602 / T-603 / T-604 (the L5 scheme + workflow infrastructure — already on `main`).
- **Est:** 4h (mock container + launch-arg plumbing + L3 smoke method + two L5 journey methods + the L1 no-account assertions).
- **||:** P15-cloudkit-sync (the PR for T-708 carries the `e2e` label so the L5 job runs per CL-58's gating policy). T-708 owns `MockCKContainer.swift` + the new SmokeTests + E2EJourneys methods exclusively.

---

## Phase 16 — Site/app design coordination (2026-05-29)

Graduates the round-9 "Site ↔ app design coordination" backlog entry (US-43 / CL-103..CL-107). Closes the seven measurable visual gaps between dutchovendaddy.com and the iOS app over four phases. Phase a (T-710) ships the foundational tokens + typography; Phases b–d (T-711..T-713) deliver the visible compositional changes behind a `DODFeed.layoutVariant` flag so each screen reverts independently if a regression surfaces on real device.

### T-710 — Phase a: design tokens + typography + L4 baseline re-record (US-43)

- **What:** flip `Surface` light to `#FFFFFF`, collapse `SurfaceElevated` to `#FFFFFF` light, add `SurfaceWarm` (`#FAF6EE` / `#281F19`) and `LabelOnAccent` (`#FFFFFF` / `#FFFFFF`) tokens, rename `CreamSubtle` → `SurfaceDivider` (`#E6DECF` / `#3D2B1F` — the dark variant is now distinct), shift `DODType.displayLarge` + `displayMedium` from `.semibold` to `.bold`, switch `heading` + `caption` to SF Rounded (`design: .rounded`), add `DODType.brand` (`.system(size: 22, design: .rounded, weight: .bold)`). Re-record every L4 snapshot baseline that resolves any of the shifted tokens.
- **Files:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Resources/Colors.xcassets/{Surface,SurfaceElevated,SurfaceWarm,SurfaceDivider,LabelOnAccent}.colorset/Contents.json` (delete `CreamSubtle.colorset`), `Packages/DODDesignSystem/Sources/DODDesignSystem/Colors.swift`, `Packages/DODDesignSystem/Sources/DODDesignSystem/Typography.swift`, `Packages/DODDesignSystem/Tests/DODDesignSystemTests/ColorsTests.swift`, and every `__Snapshots__/**.png` in the workspace that pixel-diffs against the new tokens (expected 60–80 PNGs across `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/` + `Packages/DODFeatureFeed/Tests/DODFeatureFeedTests/__Snapshots__/` + the other feature packages' snapshot directories).
- **AC:** 43.1, 43.2, 43.3, 43.4, 43.5, 43.6, 43.7, 43.8, 43.9, 43.10, 43.11.
- **Est:** ~3 days (~12h: 2h token + Swift edits, 1h spec graduation, 6h baseline re-record across packages, 2h verify + PR, 1h launch-on-sim QA pass).
- **||:** P16-design-coordination (the PR carries no `e2e` label; the changes are token-level and L4-baseline-only, no behavior change). T-710 owns every `__Snapshots__/**` PNG it re-records exclusively for this PR; if a parallel branch also touches a snapshot file T-710 owns, T-710's value wins because it is the systematic-token regenerate.

#### T-711 — Phase b: magazine `RecipeCard` variant behind `DODFeed.layoutVariant` flag (US-43, deferred)

- **What:** new gallery-grid `RecipeCard` variant — drop card chrome, switch hero to 3:4 portrait full-bleed, photo + title only (Move 6 brave call deferred to CL on this PR per CL-107). `RecipeCard.ListRow` unchanged. New `DODFeed.layoutVariant` UserDefaults flag + Settings → Layout toggle. L4 baselines for both variants.
- **Files:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/RecipeCard.swift` (new `Magazine` subtype variant), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (variant selection), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/SettingsView.swift` (new Layout row), plus snapshot baselines.
- **AC:** to be assigned (43.12–43.15 reserved).
- **Est:** ~1 week (~30h).
- **||:** depends on T-710 landing first (the magazine variant resolves `Surface` → `#FFFFFF`).

#### T-712 — Phase c: nav-bar masthead + `DODBadge.Numbered` component (US-43, deferred)

- **What:** Replace the `"Recipes & Articles"` text title with a circular 32pt DOD logo (reuse `App/AppIcon.icon/Assets/DOD Master.png`). Tap-to-scroll-to-top behavior. New `DODBadge.Numbered(_ n: Int)` component — 28pt burnt-orange circle with SF Rounded white digit + drop shadow. Apply to Feed's "Featured" / "This Week" rail only.
- **Files:** `App/RootView.swift` (toolbar leading), `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/DODBadge.swift` (new), `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` (Featured rail). New L4 baselines for `DODBadge.Numbered`.
- **AC:** to be assigned (43.16–43.18 reserved).
- **Est:** ~3 days (~12h).
- **||:** depends on T-710 + T-711 landing first (the badge uses `LabelOnAccent`, the masthead expects the magazine layout).

#### T-713 — Phase d: Recipe Detail surface polish (US-43, deferred)

- **What:** Recipe Detail picks up the surface change + uses portrait hero at top. Comments + ratings sections inherit the new surface tier. Saved tab adopts `SurfaceWarm` (the warmth lands where the user is "at home"). Cook Mode background adopts `SurfaceWarm` (warm under low-light).
- **Files:** `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/{RecipeDetailView,CommentsSection,RatingsSection,CookModeView}.swift`, `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift`. Snapshot baselines for each.
- **AC:** to be assigned (43.19–43.20 reserved).
- **Est:** ~3 days (~12h).
- **||:** depends on T-710 + T-711 + T-712 landing first.

---

## Summary

- **Total tasks:** 73 (Phase 1–5) + 6 (Phase 6 consultant pass) + 5 (Phase 7 comments + ratings) + 6 (Phase 8 polish: T-310, T-320, T-321, T-322, T-323, T-330) + 5 (Phase 8 follow-ups surfaced by T-330: T-331, T-332, T-333, T-334, T-335) + 1 (Phase 9 categories modernization: T-340) + 16 (Phase 10: T-350, T-360, T-361, T-370, T-380, T-390, T-391, T-392, T-393, T-580, T-610, T-590, T-620, T-630, T-631, T-640) + 10 (Phase 12 Shopping List: T-680, T-681, T-682, T-683, T-684, T-685, T-686, T-687, T-688, T-689) + 9 (Phase 15 CloudKit sync: T-700, T-701, T-702, T-703, T-704, T-705, T-706, T-707, T-708) = 131
- **Total estimate:** ~143 hours + ~17 hours (Phase 6) + ~19 hours (Phase 7) + ~13 hours (Phase 8) + ~9 hours (Phase 8 follow-ups) + ~2 hours (Phase 9) + ~13 hours (Phase 10) + ~19 hours (Phase 12) + ~29 hours (Phase 15) = ~264 hours
- **Critical path:** Cluster A → Domain (T-010, T-011) → Networking (T-058) → Recipe Detail (T-110..T-121). Roughly 6 weeks at one focused contributor; 3–4 weeks with two contributors using the parallelism tags.
- **Parallel clusters once Cluster A lands:** B-domain, B-support, B-design, B-analytics can all run simultaneously.
- **Parallel clusters once Cluster C + D land:** E-feed, E-cats, E-search, E-detail, E-saved can all run simultaneously (Saved depends on Detail finishing the offline path).
- **Phase 6 parallelism:** F6-cards, F6-icon, F6-detail, F6-onb can all run in parallel. F6-cook (T-304, T-305) is the only sequential thread inside Phase 6.
- **Phase 8 parallelism:** P8-tab (T-310) and P8-darkmode (T-330) are fully independent. The widget cluster sequences T-320 → T-321 → T-322 → T-323 internally but is independent of P8-tab and P8-darkmode externally. So three worktrees can run simultaneously: one on T-310, one on T-320 (then handing forward inside the cluster), one on T-330.
- **Phase 9 parallelism:** P9-categories (T-340) is independent of every Phase 8 task and is the only Phase 9 work item.
- **Phase 10 parallelism:** P10-search (T-350 + T-500), P10-glyph (T-380), P10-latest-widget (T-360 → T-361), P10-lockscreen (T-370), P10-widget-appearance (T-390 → T-394 / T-395), P10-saved-desc (T-400), P10-detail-cleanup (T-410), P10-livetests (T-420), and P10-categories-brown (T-430) are independent of every Phase 8 + Phase 9 task and of each other. T-500 (Search-tab polish bundle) amends T-350's AC-20.3 carve-out and is bounded entirely to `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` + `SearchViewModel.swift` — independent of every other Phase 10 task source-wise. Parallel with T-510 (new-recipe surfacing, networking-only — different code path) and T-520 (color overhaul, `DODColor` token-level — different surface); if T-520 re-records any `SearchView` snapshot file T-500 also touches, T-500's semantic changes win because T-500 owns `SearchView.swift` for round 6. T-360 → T-361 sequences internally (T-361 consumes the `WidgetImageBridge` T-360 introduces). T-380 assumes T-310 already shipped. T-370 (lock-screen widget) ran on a parallel branch and conflicted with T-360 only on `Widget/DODAppWidgetBundle.swift` (each adds a registration line), resolved by the later PR rebasing on the first. T-390 is an audit-style task that touches `WidgetCard.Hero` (via a surgical `widgetAccentedRenderingMode(.fullColor)` opt-out) and adds new Tinted/Vibrant snapshot baselines — independent of T-360/T-361's image-bridge work (the audit doesn't depend on real-image render, only on the widget composition itself), and explicitly scoped to home-screen widgets so T-370's lock-screen widget code is not touched. T-400 is a single-string rewrite of `SavedRecipesWidget`'s gallery description — independent of every other Phase 10 entry (no shared files; touches only `Widget/SavedRecipesWidget.swift`'s description argument). T-410 (recipe detail cleanup) amends T-302's Phase 6 polish decision and assumes T-380 already shipped the bookmark glyph on the nav-bar Save — it touches `RecipeDetailView` + `RecipeDetailFloatingActions` + `CommentComposer` and is independent of every other Phase 10 task. T-420 (L2 nightly test for new-recipe surfacing) lives entirely inside `Packages/DODIntegrationTests/Tests/` — touches no source code, runs only in the nightly job per AC-T3, and shares no files with any other Phase 10 task. T-430 amends T-340's `CategoryListView` surface color and re-records the six `CategoryListViewSnapshotTests` baselines — bounded entirely to `Packages/DODFeatureCategories/**`, so it does not touch any widget surface, any other tab, or any DesignSystem token. T-394 (Featured widget contrast fix) and T-395 (Saved widget contrast audit verdict, clean) run on parallel branches against T-390's audit miss — both branches add their own copy of CL-46 + AC-23.7 and collide deliberately at merge time on `specs/dod-ios-app/{clarifications.md,spec.md,tasks.md,backlog.md}`; whoever lands second amends the existing CL-46 entry to fold both audits' framings. T-395 ships zero source edits (clean audit verdict) so the source-side merge is collision-free with T-394's `WidgetCard.swift` strengthening. New tasks added to Phase 10 should explicitly declare their parallelism tag and any cross-cluster dep.
- **Phase 11 parallelism:** P11-test-pyramid (T-600 through T-605) sequences internally — T-600 produces the audit doc that motivates T-601's spec amendment; T-601 locks the scheme name + four CI trigger surfaces; T-602 stands up the target + scheme; T-603 lands the five seed journeys against the target; T-604 wires the CI workflow that invokes the scheme; T-605 documents the label-gating policy for PR authors. The cluster is independent of every Phase 8 / 9 / 10 task. The branch (`feat/T-400-test-pyramid-l5-e2e`) carries all six commits and lands as a single merge commit (CONTRIBUTING.md "merge commit for multi-task clusters that need history preserved"). Follow-ups (T-610: host-side fake-dependencies switch; T-611: comments/ratings POST-path coverage against a stub; T-612: migrate de-facto-E2E methods out of `UITests/SmokeTests.swift`) are deliberately deferred — see `test-pyramid-audit.md` "Followups" section.
- **Phase 15 parallelism:** P15-cloudkit-sync sequences internally with limited parallelism after T-700 + T-701 + T-702 land. The DAG is: T-700 (spec, no deps) → T-701 (entitlements + container, depends on T-700) → T-702 (sync adapter, depends on T-701 because the adapter's `ModelConfiguration(_:groupContainer:cloudKitDatabase: .private(...))` call requires the entitlement) → {T-703 (Settings toggle), T-706 (conflict resolution) — independent of each other, both depend on T-702}; T-704 (opt-in sheet) depends on T-702 + T-703 (the `dod.cloudKitSyncEnabled` flag is shared); T-705 (offline queue + status surface) depends on T-702 + T-703 (the `CloudKitSyncStatus` enum the Settings sublabel reads); T-707 (analytics + §9 amendment) depends on T-702 + T-703 + T-704 (the dispatch sites); T-708 (L1 + L3 + L5 tests, gated by `e2e` label per CL-58) depends on T-702 + T-703 + T-704 + T-707 (the full feature surface). Two contributors can parallelize after T-702 lands by splitting T-703 (Settings UI) and T-706 (merge policy); after T-703 lands, T-704 (opt-in sheet) and T-705 (status surface) fan out. Phase 15 is independent of every Phase 8 / 9 / 10 / 11 / 12 task source-wise — owns `Packages/DODPersistence/Sources/DODPersistence/{CloudKitSyncAdapter,CloudKitSyncStatus,LastWriteWinsMergePolicy,MockCKContainer}.swift` (new), `Packages/DODAnalytics/Sources/DODAnalytics/SyncErrorCategory.swift` (new), `Packages/DODFeatureOnboarding/Sources/DODFeatureOnboarding/CloudKitOptInSheet.swift` (new), and additive extensions to `Packages/DODPersistence/Sources/DODPersistence/{CachedRecipe,RecipeStore,RecipeStore+Containers}.swift` (the `modifiedAt` field + per-write timestamp settings), `Packages/DODFeatureSettings/Sources/DODFeatureSettings/{SettingsView,SettingsViewModel,SettingsDependencies}.swift` (the iCloud Sync row), `App/{DODApp.entitlements,Info.plist,RootView,AppDependencies}.swift` (the two new entitlement keys + the `remote-notification` background mode + the opt-in sheet integration + the `CKAccountChanged` observer). T-707's constitution §9 amendment + T-700's §1 / §3 / §4 amendments are the only files outside `Packages/**` / `App/**` / `UITests/**` that this phase touches. No source-side collisions with any prior phase. The deliberately-deferred items per CL-88 (`PersistentShoppingListItem` syncing waits until T-682 lands) and CL-98 (Google Play / Android non-applicability) are NOT graduated as part of Phase 15 — they remain backlog candidates per their per-CL activation triggers.
- **Phase 12 parallelism:** P12-shopping sequences internally with two parallelizable seams. The DAG is: T-680 (spec, no deps) → {T-681 (domain + classifier), T-683 (DesignSystem primitives) — independent of each other, both depend only on T-680}; T-682 (persistence) depends on T-681 for the `Aisle` type; T-684 (view + view-model in new `DODFeatureShoppingList` package) depends on T-682 + T-683; T-685 (entry surfaces in Saved + RecipeDetail) depends on T-684; T-686 (share path) depends on T-684; T-687 (analytics + constitution §9 amendment) depends on T-684 + T-686; T-688 (L3 smoke) depends on T-684 + T-685; T-689 (L5 E2E, gated by `e2e` label per CL-58) depends on T-684 + T-685 + T-686 + T-687. Two contributors can parallelize after T-680 lands by splitting T-681 and T-683; once T-682 + T-683 are in, T-684 is the bottleneck (single owner) but then T-685 / T-686 fan out again. Phase 12 is independent of every Phase 8 / 9 / 10 / 11 task source-wise — owns `Packages/DODFeatureShoppingList/**` (new), `Packages/DODDomain/Sources/DODDomain/Aisle.swift` (new), `Packages/DODSupport/Sources/DODSupport/IngredientAisleClassifier.swift` (new), `Packages/DODPersistence/Sources/DODPersistence/{ShoppingListItem,SchemaV4}.swift` (new + rewrite), `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/{ShoppingListRow,AisleSectionHeader}.swift` (new), and a handful of single-line extensions on existing `Packages/DODFeatureSaved/**` + `Packages/DODFeatureRecipeDetail/**` + `Packages/DODAnalytics/**` files for the entry-surface + dispatch wiring. The constitution §9 amendment in T-687 is the only file outside `Packages/**` and `UITests/**` that this phase touches; no source-side collisions with T-660 (already merged), T-670 (Spencer, in-flight on `Packages/DODFeatureSearch/**`), or T-690 (round-3 dad Voice Mode, pending graduation on `Packages/DODFeatureRecipeDetail/**` Cook Mode surface — T-685's RecipeDetail toolbar extension touches a different region of the same package, see CL-73 for the per-call-site placement decision). The deliberately-deferred items per CL-68 (location-based notifications), CL-69 (multi-list lifecycle), and CL-71 (pantry inventory) are NOT graduated as part of Phase 12 — they remain backlog candidates per their per-CL activation triggers.

Phase 5 starts when this list is approved and T-001 is picked up. Each PR cites the T-ID + the AC IDs it implements.
