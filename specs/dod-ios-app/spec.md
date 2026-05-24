# Spec — Dutch Oven Daddy iOS App v1

**Status:** Draft, Phase 1 — Specify
**Governed by:** [`../constitution.md`](../constitution.md)

## Vision

A native iPhone and iPad reader for the Dutch Oven Daddy cooking blog. Readers can discover recipes from the home feed, browse by category, search, and save recipes so they're available while cooking — even with no internet in the kitchen.

The app is read-only: no comments, no ratings, no accounts. Recipes are the hero; UI chrome stays out of the way.

## Personas

- **Weekend Cook (primary)** — opens the app on a Saturday morning looking for "what should I make today." Browses, picks one, cooks from it.
- **Returning Reader** — has a few favorite recipes saved, wants to re-cook them, sometimes offline.
- **Recipe Hunter** — has a specific ingredient or dish in mind and searches.

## v1 scope (in)

1. Browse latest recipes (home feed)
2. Browse by category
3. Search recipes
4. View recipe detail (hero, ingredients with check, steps, video, related recipes)
5. Save recipes for offline reading
6. Share a recipe via native share sheet

## v1 scope (out — deferred to v2)

- User accounts and sign-in
- Cross-device sync (iCloud) of saved recipes
- Push notifications for new recipes
- Comments and ratings
- Meal planning / weekly calendar
- Shopping list
- Cooking mode (screen-awake, in-app timers)
- watchOS, macOS, visionOS targets

---

## User stories

### US-1 — Browse the home feed
**As a** Weekend Cook,
**I want** to open the app and immediately see the most recent recipes from the blog,
**so that** I can quickly find inspiration for what to cook.

**Acceptance criteria:**
- **AC-1.1** Given a first-time launch with internet, when the app opens, then the home feed shows the 20 most recent published recipes from dutchovendaddy.com, ordered newest-first.
- **AC-1.2** Given the home feed, when the user scrolls to the bottom, then the next 20 recipes load (infinite scroll), with a visible loading indicator while fetching.
- **AC-1.3** Given the home feed, each row shows: hero image, recipe title, short description (excerpt), and total time. No author byline.
- **AC-1.4** Given the home feed, when the user pulls to refresh, then the feed refetches and shows newly published recipes at the top.
- **AC-1.5** Given the home feed with no internet on first launch, when the app opens, then an empty state explains "You need internet to load recipes the first time" with a Retry button.
- **AC-1.6** Given the home feed has been loaded before, when the app opens offline, then the last cached feed is shown with a non-blocking banner: "Offline — showing recent recipes."
- **AC-1.7** Given any list (home, category, search, related), posts whose recipe-detail fetch + JSON-LD parse has previously failed are filtered out and not rendered. The filter resets on pull-to-refresh so newly-fixed posts can return. (See [`clarifications.md`](clarifications.md) CL-9.)

### US-2 — Browse by category
**As a** Recipe Hunter,
**I want** to see recipes grouped by category (e.g. Beef, Chicken, Desserts),
**so that** I can narrow down by the kind of meal I'm planning.

**Acceptance criteria:**
- **AC-2.1** Given the app, when the user opens the Categories tab, then a list of all WordPress categories from the blog is shown, alphabetically.
- **AC-2.2** Given the categories list, each category shows its name and the count of recipes in it.
- **AC-2.3** Given the user taps a category, when the category screen loads, then it shows only recipes in that category, in the same row format as the home feed, with infinite scroll.
- **AC-2.4** Categories with zero recipes are hidden.
- **AC-2.5** Empty categories or fetch failure: a clear empty state with a Retry button, no spinner stuck on screen.

### US-3 — Search recipes
**As a** Recipe Hunter,
**I want** to search recipes by keyword,
**so that** I can find a specific dish or use up an ingredient.

**Acceptance criteria:**
- **AC-3.1** Given the Search tab, when the user types ≥ 2 characters, then results update with a 300ms debounce.
- **AC-3.2** Search matches against recipe title and excerpt. Ingredient-body matching is **not required in v1** (call out as known gap in the empty state if results are sparse).
- **AC-3.3** Results show in the same row format as the home feed. Tapping a result opens recipe detail.
- **AC-3.4** Given a query with zero results, then an empty state shows: "No recipes match '<query>'. Try a different word."
- **AC-3.5** The search field has a Clear button when non-empty.
- **AC-3.6** Search queries are tracked via TelemetryDeck **with the query string hashed**, never raw (per constitution §9).
- **AC-3.7** Offline: search shows "Search needs internet" with a Retry on connectivity restore. Searching saved recipes locally is **out of scope for v1**.

### US-4 — View recipe detail
**As a** Weekend Cook,
**I want** to see everything I need to make a recipe on one screen,
**so that** I can cook without hunting around.

**Acceptance criteria:**
- **AC-4.1** Recipe detail shows, from top: hero image, title, short description, meta row (prep time, cook time, total time, servings).
- **AC-4.2** Ingredients section shows each ingredient as a tappable row with a checkbox. Tapping toggles a strikethrough state. Check state persists for the lifetime of the screen but is **not** saved across app launches in v1.
- **AC-4.3** Instructions section shows numbered steps, in order, with adequate line spacing for readability while cooking. Dynamic Type respected up to AX5.
- **AC-4.4** If the recipe has an embedded video (WPRM video field), then a video player is shown inline above the instructions. Tapping play starts playback; the player respects iOS PiP.
- **AC-4.5** If the recipe has no video, no empty video block is shown.
- **AC-4.6** A "Related Recipes" section shows 3–4 recipes from the same primary category at the bottom. Tapping one opens its detail.
- **AC-4.7** A Save button (heart icon) is in the navigation bar. Tapping toggles saved state with haptic feedback.
- **AC-4.8** A Share button (native share sheet) is in the navigation bar; sharing exposes the recipe's web URL.
- **AC-4.9** Recipe detail is fully usable offline if the recipe is saved (per US-5).
- **AC-4.10** VoiceOver: hero image has a recipe-title alt, ingredient checkboxes announce checked/unchecked state, steps are reachable in order.
- **AC-4.11** Recipe detail data (ingredients, instructions, prep/cook/total times, servings, nutrition, video URL) is sourced from the JSON-LD `@type: Recipe` block on the post's rendered HTML page (per CL-1). Recipe list data (title, excerpt, hero image, link, categories) is sourced from the WP REST API. The two sources are stitched into one local `Recipe` model. If JSON-LD parse fails on first detail open, the user sees no error screen — instead the post is hidden from subsequent lists per AC-1.7 and the navigation pops back with a brief snackbar "Recipe unavailable."

### US-5 — Save recipes for offline
**As a** Returning Reader,
**I want** to save recipes I love so I can cook them without internet,
**so that** spotty kitchen wifi doesn't break my cook.

**Acceptance criteria:**
- **AC-5.1** Tapping the Save button (heart) on a recipe detail marks it saved. Tapping again unsaves with a confirmation undo (snackbar).
- **AC-5.2** When a recipe is saved, the full recipe payload (text, ingredients, steps, metadata) **and** the hero image are downloaded for offline use within 5 seconds of saving on a normal connection.
- **AC-5.3** The Saved tab shows all saved recipes, newest-saved-first, in the same row format as the home feed.
- **AC-5.4** Given the device is offline, when the user taps a saved recipe, then the full recipe detail opens with no network calls and all text + hero image present.
- **AC-5.5** Inline videos in saved recipes do **not** need to play offline in v1. Show a "Video unavailable offline" placeholder if offline.
- **AC-5.6** Related recipes section is hidden when offline.
- **AC-5.7** Saved recipes persist across app launches, reinstalls **not** required (SwiftData store survives normal launch; reinstall wipes saves — known limitation, document in onboarding).
- **AC-5.8** The Saved tab shows an empty state when no recipes are saved: "Tap the heart on any recipe to save it for offline."

### US-6 — Share a recipe
**As any** reader,
**I want** to share a recipe with a friend,
**so that** I can recommend it.

**Acceptance criteria:**
- **AC-6.1** Tapping Share on recipe detail opens the native iOS share sheet.
- **AC-6.2** The shared payload is the recipe's canonical web URL on dutchovendaddy.com (not a deep link to the app in v1).
- **AC-6.3** Share action is tracked via TelemetryDeck (event: `recipe_shared`).

### US-7 — Cook Mode
**As a** Weekend Cook,
**I want** a hands-free cooking surface,
**so that** I can follow a recipe at the stove without the screen sleeping.

Added by consultant-pass amendment (CL-16, 2026-05-23). Constitution §2 was amended in the same pass to bring Cook Mode in scope for v1.0; constitution §9 documents the idle-timer toggle as a UIKit device-state change (not a new data category) and adds `cookModeStarted` to the analytics allowlist.

**Acceptance criteria:**
- **AC-7.1** Recipe detail has a prominent "Cook Now" button (visually distinct primary CTA, reachable without scrolling on iPhone 13 baseline).
- **AC-7.2** Tapping "Cook Now" opens a full-screen takeover showing the recipe title, a step counter formatted "Step N of M", the current step's instruction text in large type (Dynamic Type up to AX5 per CC-1), and a persistent ingredients drawer that the user can pull up without leaving Cook Mode.
- **AC-7.3** While Cook Mode is the foreground surface, the screen does not auto-lock. Implementation: set `UIApplication.shared.isIdleTimerDisabled = true` on entry and restore the prior value on exit. This is the only place in the app that touches `isIdleTimerDisabled`.
- **AC-7.4** Swipe-left (or tap "Next") advances one step; swipe-right (or tap "Back") reverses one step. After the last step, a "Done" state is shown with an explicit "Finish" or "Done" affordance — no auto-loop back to step 1.
- **AC-7.5** The ingredient check state from regular recipe detail (AC-4.2) carries into Cook Mode for the current screen lifetime — checking off an ingredient in Cook Mode's drawer and then exiting back to detail shows the same checks, and vice versa. State is **not** persisted across app launches (matches AC-4.2 lifetime contract).
- **AC-7.6** The user exits Cook Mode via an explicit "Done" button in the navigation bar or via the system back gesture. Either restores normal navigation (recipe detail underneath) and re-enables auto-lock per AC-7.3.
- **AC-7.7** Telemetry: a new event `cookModeStarted(recipeID:)` is sent the first time Cook Mode is entered for a given recipe during a session. It carries only the integer WP recipe ID — no free-text payload. The event is added to the constitution §9 allowlist by the consultant-pass amendment; the `AnalyticsEvent` enum gains the corresponding case in the follow-up implementation task (see plan.md Phase 6 cluster, task T-305).

### US-8 — First-launch onboarding
**As a** Weekend Cook on first cold launch,
**I want** a brief welcome explaining what the app does,
**so that** I'm oriented before I land on the feed.

Added by consultant-pass amendment (CL-17, 2026-05-23). Reverses the earlier CL-7 "no onboarding" decision after the consultant pass argued that a single-screen sheet costs almost nothing and helps first-time users recognize the heart-save and search affordances before they need them.

**Acceptance criteria:**
- **AC-8.1** On the first cold launch — gated by a single `UserDefaults` flag `dod.onboardingCompletedV1` — the app presents a single-screen modal sheet over the Feed. The sheet contains a friendly welcome line and exactly three bullets: "Browse the latest recipes from dutchovendaddy.com", "Search for what you're craving", and "Tap the heart to save any recipe for offline cooking".
- **AC-8.2** A "Get cooking" primary button dismisses the sheet and sets `dod.onboardingCompletedV1 = true`. All future cold launches go straight to Feed with no sheet.
- **AC-8.3** iPad first launch shows the same single-screen sheet (same content, same flag) — no separate iPad onboarding flow. The sheet sizes appropriately for iPad via standard SwiftUI `.sheet` presentation; the flag is shared with iPhone since saves and UserDefaults are per-install (consistent with AC-5.7 / CL-5).

### US-9 — Home-screen widget
**As a** Returning Reader,
**I want** a home-screen widget showing today's featured recipe,
**so that** I can jump straight into a new recipe without opening the app and scrolling the feed.

Added by consultant-pass amendment (2026-05-23). Constitution §2 was amended in the same pass to bring a WidgetKit extension into v1.0 platform scope. Watch / Mac / Vision targets remain out. The widget ships as a separate `app-extension` target `DODAppWidget` (NSExtensionPointIdentifier `com.apple.widgetkit-extension`) embedded in the host app bundle.

**Acceptance criteria:**
- **AC-9.1** A "Today's Recipe" widget is available in the iOS widget gallery in both `systemSmall` (square) and `systemMedium` (wide) sizes. Small surfaces hero + title + total-time chip on a gradient overlay; medium surfaces hero on the left with a "Today on DOD" eyebrow, title, excerpt, and total-time chip on the right. Large + Lock Screen accessory families are deferred to v2 (documented in `Marketing/TestFlight.md`).
- **AC-9.2** Tapping the widget deep-links into the app via `dod://recipe/<id>` for a populated widget, or `dod://feed` for the placeholder. The app handles the URL in `RootView.onOpenURL`, switches the active tab to Feed, and pushes the recipe-detail screen (or clears the navigation stack for `dod://feed`). The push uses the cached `RecipeListItem` when available and otherwise falls back to the widget snapshot's own copy of title/hero/excerpt so the detail screen opens instantly even when the cache is cold.
- **AC-9.3** The widget timeline refreshes every 4 hours **or** sooner — the app calls `WidgetCenter.shared.reloadAllTimelines()` after every successful feed load so a fresh top-of-feed item appears within seconds of the user pulling-to-refresh. Data flows via the shared App Group `group.com.dutchovendaddy.DODApp`: `WidgetSnapshotStore` writes the top 5 list items (`id`, `title`, `excerpt`, `heroImageURL`, `canonicalURL`, `publishedAt`, `totalTimeDisplay`) to a UserDefaults key under that suite; the widget's `TimelineProvider` reads the same key. Snapshots carry a `version` tag — readers on a mismatched version return `nil` and the widget surfaces the placeholder per AC-9.4.
- **AC-9.4** When no snapshot exists (first launch, App Group unavailable in a non-provisioned build, or a version mismatch), the widget shows a placeholder layout that says "Open the app to see today's featured recipe here." rather than a crash or a blank panel. The placeholder is also what WidgetKit hands the gallery preview so the widget renders nicely while the user is still picking a size.

### US-10 — App Intents + Siri Shortcuts
**As any** user,
**I want** to ask Siri to open a recipe by name or start cooking,
**so that** I can hand-free my way into the app.

Added by consultant-pass tier-3 amendment (2026-05-23). Wires the existing recipe corpus into Apple's AppIntents framework so the app surfaces in Spotlight, Siri, the Shortcuts app, and Action Button automations without the user having to manually configure anything. No new analytics events — invocations rely on the existing `.recipeView` / `.cookModeStarted` events that fire whenever the corresponding view appears, regardless of entry vector (see constitution §9 note below).

**Acceptance criteria:**
- **AC-10.1** Three `AppIntent`s are registered with the system: `OpenRecipeIntent(recipe:)`, `StartCookModeIntent(recipe:)`, and `OpenSavedRecipesIntent` (no parameters). The `recipe` parameter is a `RecipeEntity` whose `EntityQuery` resolves by id via `RecipeStore.recipeWithoutTouching(id:)` (the silent accessor — Siri surfacing must not pollute the LRU `lastViewedAt` ordering) and whose `suggestedEntities()` returns the union of saved + `recentlyViewed(limit:)` rows, deduplicated by id. Both store accessors are exercised by unit tests in `DODPersistenceTests.RecentlyViewedTests` (US-10).
- **AC-10.2** Each intent's `perform()` posts a `DeepLinkIntent` to the shared `DeepLinkDispatcher`; `RootView` observes the dispatcher and routes the intent into tab + NavigationStack state. The same URL grammar — `dod://recipe?id=<int>`, `dod://recipe/cook?id=<int>`, `dod://saved` — is also accepted by SwiftUI's `onOpenURL`, so any externally-launched URL behaves identically to an intent invocation. The `dod` scheme is registered in `project.yml` via `CFBundleURLTypes`. The pure parser (`DeepLinkIntent.parse(_:)`) lives in `DODSupport` and is locked by `DODSupportTests.DeepLinkIntentTests`.
- **AC-10.3** On every cold launch, `RootView.indexSpotlight()` writes the current saved + recently-viewed entities to `CSSearchableIndex.default()` as `CSSearchableItem`s (the iOS-17-compatible path; `indexAppEntities(_:)` requires iOS 18+). Tapping a Spotlight result re-launches the app via `onContinueUserActivity(CSSearchableItemActionType)` and routes through the same `handle(intent:)` path as Siri.
- **AC-10.4** `DODShortcuts: AppShortcutsProvider` registers all three intents with the system so they show up in the Shortcuts app and Spotlight automatically. Phrases include "Open ${recipe} in Dutch Oven Daddy", "Start cooking ${recipe} in Dutch Oven Daddy", and "Show my saved recipes in Dutch Oven Daddy". Per Apple's iOS 17 AppIntents guidance, every parameterized phrase contains `\(.applicationName)` — the framework rejects the build otherwise. Donation strategy: we rely on `AppShortcutsProvider` auto-discovery rather than per-detail-open `IntentDonationManager` calls (iOS 17 honors the static phrase list at install time, so per-view donations are redundant for the three top-level surfaces shipped here).

**Constitution §9 note:** intent invocations do NOT add new tracked events. `OpenRecipeIntent` lands on the detail screen, which fires the existing `.recipeView` event from `RecipeDetailViewModel.onAppear()`. `StartCookModeIntent` additionally triggers the existing `.cookModeStarted` event via the auto-presentation path. App Privacy posture is unchanged.

---

## Cross-cutting acceptance criteria

These apply to every screen, not just one story.

- **CC-1 Accessibility:** every interactive element has a VoiceOver label; every screen respects Dynamic Type up to AX5; contrast meets WCAG AA in light and dark mode (per constitution §7).
- **CC-2 Offline banner:** any screen that depends on network shows a non-blocking offline banner when connectivity is lost; the banner auto-dismisses on reconnect.
- **CC-3 Loading states:** every async fetch shows a skeleton or spinner within 100ms; never a blank screen.
- **CC-4 Error states:** every fetch failure shows a human-readable message + Retry button. No raw error codes shown to users.
- **CC-5 Analytics scope:** only the events enumerated in constitution §9 are sent. No new event types without a constitution amendment.
- **CC-6 App Privacy label:** v1 collects only Usage Data (Product Interaction), not linked to identity, not used for tracking. The App Store privacy questionnaire must match this exactly.
- **CC-7 Performance:** screens hit the budgets in constitution §8 (cold launch <1.5s, 60fps lists, recipe detail open <300ms cached / <1.5s fetched).
- **CC-8 iPad layouts:** every screen has an adaptive iPad layout. List + detail uses `NavigationSplitView` on iPad (sidebar + content), stack on iPhone.
- **CC-9 Visual density (added by consultant-pass amendment, CL-18):** the four list surfaces — Feed (US-1), Categories recipe lists (US-2), Search results (US-3), and Saved (US-5) — render as a **2-column grid** on compact horizontal size class (iPhone in portrait) and a **3-column grid** on regular horizontal size class (iPad and large iPhones in landscape). The previous 1-column compact default is retired. RecipeCard hero image height is tuned so at least **3 rows are visible above the fold** on iPhone 13 baseline in light mode at default Dynamic Type. Plan T-300 implements; snapshot tests at iPhone 13 + iPad 12.9" lock the new layout.

---

## Non-functional requirements

- **NFR-1 Offline-first cache:** the most recent 100 viewed recipes are cached automatically (LRU). Saved recipes are pinned and not evicted.
- **NFR-2 Image cache budget:** disk image cache capped at 200 MB; oldest unsaved-recipe images evicted first.
- **NFR-3 No surprise data use:** background refresh disabled by default; the app does not fetch when not in foreground in v1.
- **NFR-4 App Store readiness:** App Privacy questionnaire, screenshots for 6.5" and 6.7" iPhone + 12.9" iPad, and a marketing description are part of the release definition of done (Phase 5 task).

---

## Test pyramid (added by Phase 6 amendment 2026-05-23)

Two production bugs surfaced on first simulator run (TelemetryDeck pre-init crash; missing hero images because `_fields` filtered out `_embed` payload). Neither was caught by L1 unit tests with fake dependencies — both required an actual app launch hitting the real backend.

Mandates (per constitution §6):

- **AC-T1** Every PR runs L1 (unit), L3 (UI smoke), L4 (visual regression). Failing any blocks merge.
- **AC-T2** L3 smoke must cover: app launch without crash, all four tabs reachable, feed shows at least one recipe with a non-placeholder hero image, recipe detail open + back, save toggle visible.
- **AC-T3** L2 live-API integration runs nightly. Failing layer raises an issue but does not block in-flight PRs; treat it as a contract-drift early warning.
- **AC-T4** Regression tests for bugs surfaced post-launch must land in the same PR as the fix. Specifically:
  - **REG-1**: L3 test that the app launches without crashing when no `TelemetryDeckAppID` is set in Info.plist.
  - **REG-2**: L2 test that `WPRestClient.posts()` returns at least one item with a non-nil `heroImage` URL.
  - **REG-DOD-NAV-1**: tapping a recipe row pushes the detail screen and it stays pushed. Failure mode: `RecipeStore.cache(listItem:)` dropped `canonicalURL` on insert, so the detail fetch fell back to the homepage, JSON-LD parse failed, and AC-4.11's auto-dismiss popped the user back to the feed. Locked by `DODPersistenceTests.canonicalURLRoundTrips`, `DODPersistenceTests.canonicalURLUpdatesButDoesNotClobberOnNil`, and `SmokeTests.test_recipeDetailOpensAndShowsContent`.
  - **REG-DOD-LIST-SCROLL**: vertical drag inside a recipe row scrolls the surrounding list. Failure mode: `Button { } label: { RecipeCard }.buttonStyle(.plain)` inside a `LazyVGrid` inside a `ScrollView` swallowed the pan gesture on iOS 26. Locked by `SmokeTests.test_feedScrollsToRevealMoreRecipes`.
  - **REG-INFO-PLIST-CLOBBER**: `xcodegen generate` must not strip launch-screen / orientation keys from `App/Info.plist`. Failure mode: those keys lived only in the hand-maintained plist; XcodeGen rewrote it from `project.yml` on every regenerate, silently re-introducing the iOS letterbox bug. Locked by keeping the keys in `project.yml`'s `info.properties` block; `SmokeTests.test_appLaunchesWithoutTelemetryAppID` proves the app renders at launch (does not yet pixel-verify edge-to-edge — noted gap).
  - **REG-9**: the widget snapshot wire format the host app writes (`WidgetSnapshotStore.write`) round-trips losslessly through the widget extension's reader, and the small/medium widget layouts don't drift visually. Locked by `WidgetSnapshotStoreTests` (DODSupport: round-trip, max-entries cap, version-mismatch rejection, clear), `WidgetDeepLinkParserTests` (DODSupport: 8 cases covering `dod://recipe/<id>` and `dod://feed` plus rejection of malformed and hostile URLs), and `DesignSystemSnapshotTests.test_widgetCard_{small,medium}_populated` + `test_widgetCard_placeholder` (DODDesignSystem: pixel-locked baselines for the three layouts).
  - **REG-10**: deep-link URLs from App Intents / Siri Shortcuts / Spotlight must round-trip through `DeepLinkIntent.parse(_:)` and `DeepLinkIntent.url` without losing their target id or action. Failure mode would be Siri opening the wrong recipe (or the homepage) when a user says "Open Bourbon Berry Cake" — silently incorrect from the user's perspective. Locked by the round-trip cases in `DODSupportTests.DeepLinkIntentTests` and the entity-lookup tests in `DODPersistenceTests.RecentlyViewedTests` (`recipeWithoutTouchingDoesNotBumpLastViewedAt` in particular, which guards against Siri suggestions promoting the wrong recipe in subsequent LRU queries).

## Clarifications

Phase 2 is closed. See [`clarifications.md`](clarifications.md) for the resolution of all 10 clarification items and the rationale behind each. Notable outcomes baked into the spec above:

- Hybrid fetch strategy: WP REST for lists, post-page JSON-LD for recipe details (CL-1, AC-4.11).
- Per-page = 20 (CL-2); categories only, no tags (CL-3); share URL = `post.link` (CL-4).
- Saves stay device-local in v1; iCloud sync = v2 (CL-5).
- iPad hero image up to 2048px from `media_details.sizes`; lists use `medium_large` (CL-6).
- No onboarding (CL-7); branding follows the blog, palette tokenized in `plan.md` (CL-8).
- Posts with unparseable Recipe JSON-LD are hidden from lists after first failure (CL-9, AC-1.7).
- Non-recipe-post handling deferred to a Phase 3 post-mix audit (CL-10).
