# Clarifications — Dutch Oven Daddy iOS App v1

**Status:** Phase 2 — Clarify, in progress
**Governs:** [`spec.md`](spec.md) — update affected ACs when these resolve.

## Method

Resolved questions are dated and traceable. Each resolution lists which acceptance criteria it touches so the spec stays in sync.

---

## Resolved by API research (2026-05-23)

### CL-1 — WPRM recipe data is NOT available as structured JSON via REST
**Question:** Does the WP REST API expose WPRM recipe fields (ingredients, steps, video, times) as structured data?

**Finding:**
- The default `wp/v2/posts` endpoint returns recipe content only as HTML embedded inside `content.rendered`.
- The `wp-recipe-maker/v1` namespace exists but has no public route returning structured recipe JSON. `embed/{id}` returns rendered HTML; `manage/*` requires admin auth.
- The `yoast_head_json.schema` on the API response does **not** include `@type: Recipe`.
- **However:** the rendered post HTML page contains a `<script type="application/ld+json">` block with a full `@type: Recipe` object including `recipeIngredient`, `recipeInstructions`, `prepTime`, `cookTime`, `totalTime`, `recipeYield`, `image`, and `nutrition`. This is highly structured and standardized.

**Resolution:** **Hybrid fetch strategy.**
1. Recipe **list** screens (home feed, category, search results, related, saved) use the WP REST API. Cheap, paginated, JSON.
2. Recipe **detail** screens fetch the rendered HTML page (`post.link`) and parse the JSON-LD `Recipe` block to get structured ingredients/instructions/times/nutrition.
3. The JSON-LD parse is the single source of truth for recipe body content. WPRM HTML scraping is **not** allowed as a primary path (constitution §4 already bans HTML scraping as primary).

**Acceptance criteria impact:**
- **AC-4.1 / AC-4.3 / AC-4.6:** times, ingredients, instructions sourced from JSON-LD.
- New **AC-4.11** to add: recipes without a parseable `Recipe` JSON-LD block must not appear in feed/search/category lists; they're filtered server-side... wait, the WP API can't filter on this. Filtered client-side after detail-fetch. See CL-9 below.

### CL-2 — Pagination
**Question:** What's the WP REST API per-page cap?
**Resolution:** WordPress default max is `per_page=100`. We use **`per_page=20`** for all list fetches (matches AC-1.2 batch size). Server may return fewer when fewer remain.

### CL-3 — Categories vs Tags
**Question:** Does "category" mean WP categories, tags, or both?
**Resolution:** **WP categories only** in v1. Sample post showed 2 categories, 0 tags. Tags are not populated on this site. Revisit if blog adds tag usage post-launch.

**Acceptance criteria impact:** AC-2.1 — "all WordPress categories" stays as written.

### CL-4 — Canonical recipe URL
**Question:** What URL goes in the share sheet?
**Resolution:** Use `post.link` verbatim. Confirmed hostname is `www.dutchovendaddy.com` (not bare `dutchovendaddy.com`). Don't rewrite or normalize.

**Acceptance criteria impact:** AC-6.2 — share payload is exactly `post.link`.

---

## Resolved by spec-default re-affirmation

### CL-5 — iCloud sync for saved recipes
**Question:** Should "Save" require iCloud opt-in immediately, or stay device-local in v1?
**Resolution:** **Device-local SwiftData in v1.** iCloud / CloudKit sync is explicitly deferred to v2 (already in spec out-of-scope). AC-5.7 stands; reinstall wipes saves and that's documented as a known limitation.

### CL-6 — Hero image resolution for iPad
**Question:** Minimum image size for iPad hero?
**Resolution:** Use the WP `media_details.sizes` map and pick the largest available size up to `2048px` on the long edge for iPad detail hero. Fall back: `full` size if no `2048x2048` derivative exists. Lists use `medium_large` (~768px). Don't request `full` for lists — wasteful.

---

## Resolved by user decision (2026-05-23)

### CL-7 — First-launch onboarding
**Question:** Onboarding screen on first launch?
**Resolution:** **No onboarding.** App opens directly to the home feed. Recipe-app intent is obvious from the first frame; faster time-to-value. No US-7 added.

### CL-8 — App icon and color palette
**Question:** App icon and color palette decided?
**Resolution:** **Use the blog's existing branding.** Owner will provide the logo / icon asset. The DesignSystem palette (warm earth tones — to be sampled from dutchovendaddy.com hero imagery and navigation) is defined as a Phase 3 (Plan) task. Spec stays branding-agnostic; design tokens live in `plan.md`.

### CL-9 — Posts with no parseable Recipe JSON-LD
**Question:** What does the app do for a post missing JSON-LD `Recipe`?
**Resolution:** **Hide the post entirely.** Filter at the list layer. A user must never reach a detail screen that can't render. Implementation: when a post's detail fetch + JSON-LD parse fails for the *first* view, the post is added to a per-install blocklist and removed from subsequent list renders. We *attempt* parse lazily (not eagerly for every list item — would tank performance) and treat the first-failure as ground truth until the next pull-to-refresh.

**Acceptance criteria impact:** new **AC-1.7** and new **AC-4.11** in `spec.md`.

### CL-10 — Non-recipe posts (roundups, articles)
**Question:** Include non-recipe posts as articles, or filter out?
**Resolution:** **Punt to Phase 3.** Plan step will sample ~50 recent posts from the live blog, count how many lack Recipe JSON-LD, and decide based on real data. If <5% are non-recipe, CL-9's hide-on-missing logic absorbs them. If higher, we revisit and may add an Article view. Spec marks this as a **TBD: post-mix audit** in `plan.md`.

---

## Phase 2 status: CLOSED

All 10 clarifications resolved. Spec deltas applied below. Ready for Phase 3 — Plan.

---

## Phase 6 amendments (post-launch)

Bugs surfaced after v1.0 was feature-complete. Each is locked by a regression test (see `spec.md` "Test pyramid" section) so it can't silently regress.

- **CL-11 (2026-05-23)** — TelemetryDeck SDK fatal-errors when `signal()` runs before `initialize()`. Fix: transport guards its own `configured` flag. Locked by REG-1. Commit `74231c9`.
- **CL-12 (2026-05-23)** — WP REST `_embed=wp:featuredmedia` is silently dropped when `_fields` is also requested. Fix: omit `_fields` when using `_embed`. Locked by REG-2. Commit `74231c9`.
- **CL-13 (2026-05-23)** — `RecipeStore.cache(listItem:)` dropped `canonicalURL` on insert, so recipe detail navigation auto-dismissed (AC-4.11) on JSON-LD parse failure. Locked by REG-DOD-NAV-1. Commit `14e4cf9`.
- **CL-14 (2026-05-23)** — `Button` + `LazyVGrid` + `ScrollView` swallows pan gestures on iOS 26, making the feed un-scrollable. Locked by REG-DOD-LIST-SCROLL. Commit `130aa18`.
- **CL-15 (2026-05-23)** — `xcodegen generate` clobbers hand-edited `App/Info.plist` keys (launch screen, orientations) that aren't mirrored in `project.yml`. Locked by REG-INFO-PLIST-CLOBBER. Commit `0c98f6e`.
- **CL-16 (2026-05-23)** — **Cook Mode is in scope for v1.0.** Was an implicit non-feature before (constitution §2 had "Cooking mode (screen-awake, in-app timers)" in spec out-of-scope; this amendment promotes the screen-awake half — no in-app timers yet). Spec amendment via new **US-7** with seven ACs covering the Cook Now button, full-screen takeover, `isIdleTimerDisabled` toggle, swipe/tap step navigation, shared ingredient-check state, exit affordances, and `cookModeStarted` telemetry. Constitution §2 amended to list Cook Mode as in-scope; §9 amended to document the idle-timer toggle as a UIKit device-state change (not new data collection) and to add `cookModeStarted` to the analytics allowlist. Authorized by consultant-pass approval.
- **CL-17 (2026-05-23)** — **Onboarding sheet is in scope for v1.0.** Reverses **CL-7** ("No onboarding"). The consultant-pass argument was that a single-screen, single-button welcome sheet costs ~30 minutes of build time and meaningfully helps first-time users find the heart-save and search affordances. Spec amendment via new **US-8** with three ACs covering the one-time sheet, `dod.onboardingCompletedV1` UserDefaults flag, "Get cooking" dismiss button, and the iPad-same-as-iPhone behavior. CL-7 is now superseded; subsequent readers should treat US-8 as the controlling decision.
- **CL-18 (2026-05-23)** — **Compact layout default is 2-column grid (was 1-column).** Plan §0 / Cluster G previously specified a one-column compact layout in `T-150`; consultant pass argues a denser grid better matches the "browse for inspiration" primary job. Spec amendment via new cross-cutting **CC-9** covering Feed, Categories, Search, and Saved at 2-column compact / 3-column regular, with the RecipeCard hero height tuned to keep ≥3 rows above the fold on iPhone 13 baseline. Implementation tracked in plan.md Phase 6 cluster, task T-300.
- **CL-19 (2026-05-23)** — **Local ingredient index sourced from JSON-LD parses, not from a WP API change.** Recipe Hunters frequently want to search by ingredient (the AC-3.2 wording even calls it out as a known v1 gap). CL-1 already established that the WP REST API does not expose a recipe-body / ingredient field; extending it server-side is out of scope. Resolution: maintain a **local-only** `CachedIngredient` SwiftData table populated as a side effect of `RecipeStore.mergeDetail(_:)`. Each detail open writes its parsed ingredients into the index; subsequent searches run a REST title/excerpt pass and a local ingredient pass and merge with explicit ranking (REST title > REST excerpt > local-only). SwiftData bumped V1 → V2 (lightweight, additive — no field rename or removal) — see `Packages/DODPersistence/MIGRATION.md`. New spec story **US-12** captures the full requirement; new **REG-12** locks the merger + index + filter logic with unit tests. (Note: the original task brief proposed naming this CL-16; renumbered to CL-19 because CL-16 already documents Cook Mode.)

## Phase 7 amendments (comments + ratings, 2026-05-24)

- **CL-21** — Promote "Comments and ratings" out of the v1 deferred list. Constitution §1 changes from "read-only" to "mostly read-only with two write surfaces." Constitution §9 adds guest identity (name + email in Keychain, sent only to dutchovendaddy.com), updates the App Privacy questionnaire to include Contact Info + User Content. Adds AnalyticsEvent cases `recipeRated` and `recipeCommentSubmitted` to the allowlist.
- **CL-22** — Editing/clearing the guest identity from inside the app is deferred to v1.1. v1.0 requires uninstalling to reset. Tracked here; no AC.
- **CL-23** — Rating + comment moderation: the live blog's WP Discussion settings are configured to "comment author must fill out name and email" + held-for-approval. App surfaces both states explicitly (AC-14.4). Owner accepted this UX in the dispatch question; no further amendment needed.

## Phase 8 amendments (post-Phase-6 polish, 2026-05-24)

- **CL-24 (US-16)** — Saved tab icon variant. Decision: use SF Symbol `bookmark` (outline) when the tab is unselected and `bookmark.fill` when selected. **Why:** matches iOS system convention (compare Mail's "Flagged" tab and Safari's bookmarks); avoids a custom asset; selection-aware variant is what the rest of `AppTab.systemImage` does implicitly via SwiftUI's tab styling. Considered: a custom multi-color bookmark + a single non-filling outline. The system-symbol fill behavior wins because it stays correct across iOS versions and respects user appearance settings without us touching color tokens.
- **CL-25 (US-16)** — Tab order. Decision: **Recipes → Categories → Saved → Search** (current is Recipes → Categories → Search → Saved). **Why:** Saved is the "return user" surface and deserves a thumb-zone slot; Search is the lowest-traffic surface per existing telemetry. Considered: leaving Saved at position 4 and only changing the icon. Rejected because the original ask is to "swap" the two — half-doing it would surface a second decision later. Changing `AppTab.allCases` order is the single source of truth and is what the implementing PR touches.
- **CL-26 (US-17)** — Saved-recipes widget sizes. Decision: small (1 saved recipe) + medium (3 saved recipes). **Why:** matches the existing today's-featured widget surface area; `.systemLarge` adds layout cost for a usage pattern (browsing many saves on the home screen) that doesn't yet have evidence. Considered: add `.systemLarge` showing 6 saves. Deferred to v1.1; revisit only if user testing surfaces demand.
- **CL-27 (US-17)** — Saved-recipes widget empty state. Decision: dedicated placeholder ("Save a recipe to see it here") that tap-targets to the Saved tab via a new `dod://saved` deep link. **Why:** failing silently with a blank card violates "no surprise empty states" (the same principle as AC-1.5, AC-3.4, AC-5.8). Considered: hide the widget entirely when empty. Rejected because iOS widgets don't have a hide-self affordance — the user would see a blank card; explicit copy is friendlier.
- **CL-28 (US-17)** — Saved-recipes widget refresh trigger. Decision: host app forces `WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")` whenever `SavedStore` writes or removes a saved recipe; in addition, the widget's timeline provider returns entries with a 15-minute refresh cap as a safety net for crashes or background-write paths. **Why:** the existing featured widget already uses the snapshot-then-reload pattern (see `WidgetSnapshotStore.write` + the call site in `DODApp.swift`); reusing it keeps the contract uniform across both widgets. Considered: background fetch in the widget extension. Rejected per AC-17.6 and NFR-3 (no background network in v1).
- **CL-29 (US-17)** — Saved-recipes widget tap target. Decision: tap on a recipe row deep-links to that recipe's detail (`dod://recipe/<id>`, existing US-9 parser); tap on the widget chrome (placeholder state, or whitespace around recipe rows) deep-links to the Saved tab (`dod://saved`, new parser case). **Why:** matches user mental model — tapping a card means "open this thing"; tapping background means "go to where this thing lives." Considered: route every tap to the Saved tab regardless. Rejected because it wastes the one-tap-from-cook ergonomic that the user story explicitly wants.
- **CL-30 (US-18)** — Dark-mode audit framing. Decision: structure US-18 as **audit + targeted fixes**, not as a feature with deliverables guaranteed in advance. The audit doc (`appearance-audit.md`) is the deliverable; any code change is incidental. **Why:** constitution §7 already mandates WCAG AA in both modes — US-18 enforces what's already required, surface by surface, with snapshot tests filling the gaps before any visual change so the diff is provable. Considered: opening this as a list of "known dark-mode bugs to fix." Rejected because there's no current bug list — the work is to find out, not to patch a known set. AC-18.6 explicitly authorizes a clean audit to close the story.
