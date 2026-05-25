# Spec — Dutch Oven Daddy iOS App v1

**Status:** Draft, Phase 1 — Specify
**Governed by:** [`../constitution.md`](../constitution.md)

## Vision

A native iPhone and iPad reader for the Dutch Oven Daddy cooking blog. Readers can discover recipes from the home feed, browse by category, search, and save recipes so they're available while cooking — even with no internet in the kitchen.

The app is **mostly read-only** — every recipe is a tap away without sign-in — with two write surfaces in v1.0: posting a rating (US-13) and posting a comment (US-14) on a recipe, both via the dutchovendaddy.com WordPress REST API under a Keychain-stored guest identity (US-15). No accounts. Recipes are the hero; UI chrome stays out of the way.

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
- **AC-4.7** A Save button (bookmark icon) is in the navigation bar. Tapping toggles saved state with haptic feedback. *Amended by CL-38 (T-380, 2026-05-24); supersedes the earlier "heart icon" wording, which was retained in v1 by the carve-out in AC-16.3. Original: ~~"A Save button (heart icon) is in the navigation bar."~~*
- **AC-4.8** A Share button (native share sheet) is in the navigation bar; sharing exposes the recipe's web URL.
- **AC-4.9** Recipe detail is fully usable offline if the recipe is saved (per US-5).
- **AC-4.10** VoiceOver: hero image has a recipe-title alt, ingredient checkboxes announce checked/unchecked state, steps are reachable in order.
- **AC-4.11** Recipe detail data (ingredients, instructions, prep/cook/total times, servings, nutrition, video URL) is sourced from the JSON-LD `@type: Recipe` block on the post's rendered HTML page (per CL-1). Recipe list data (title, excerpt, hero image, link, categories) is sourced from the WP REST API. The two sources are stitched into one local `Recipe` model. If JSON-LD parse fails on first detail open, the user sees no error screen — instead the post is hidden from subsequent lists per AC-1.7 and the navigation pops back with a brief snackbar "Recipe unavailable."

### US-5 — Save recipes for offline
**As a** Returning Reader,
**I want** to save recipes I love so I can cook them without internet,
**so that** spotty kitchen wifi doesn't break my cook.

**Acceptance criteria:**
- **AC-5.1** Tapping the Save button (bookmark) on a recipe detail marks it saved. Tapping again unsaves with a confirmation undo (snackbar). *Amended by CL-38 (T-380, 2026-05-24); supersedes the earlier "(heart)" wording. Original: ~~"Tapping the Save button (heart) on a recipe detail marks it saved."~~*
- **AC-5.2** When a recipe is saved, the full recipe payload (text, ingredients, steps, metadata) **and** the hero image are downloaded for offline use within 5 seconds of saving on a normal connection.
- **AC-5.3** The Saved tab shows all saved recipes, newest-saved-first, in the same row format as the home feed.
- **AC-5.4** Given the device is offline, when the user taps a saved recipe, then the full recipe detail opens with no network calls and all text + hero image present.
- **AC-5.5** Inline videos in saved recipes do **not** need to play offline in v1. Show a "Video unavailable offline" placeholder if offline.
- **AC-5.6** Related recipes section is hidden when offline.
- **AC-5.7** Saved recipes persist across app launches, reinstalls **not** required (SwiftData store survives normal launch; reinstall wipes saves — known limitation, document in onboarding).
- **AC-5.8** The Saved tab shows an empty state when no recipes are saved: "Tap the bookmark on any recipe to save it for offline." *Amended by CL-38 (T-380, 2026-05-24). Original: ~~"Tap the heart on any recipe to save it for offline."~~*

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

### US-12 — Ingredient search, filters, recents
**As a** cook,
**I want** to search recipes by ingredient and filter results by cook time, category, or what I've cooked before,
**so that** I can find what to make with what I have in 20 minutes.

Added by Tier-4 consultant-pass amendment (CL-19, 2026-05-23). Reframes AC-3.2's "ingredient-body matching is **not required in v1**" caveat. Instead of changing WP's REST surface (it can't be done without server-side work — see CL-1), the app now maintains a local SwiftData ingredient index sourced from the JSON-LD details that the detail view already parses.

**Acceptance criteria:**
- **AC-12.1** Ingredient-aware ranking. Each time a recipe's detail JSON-LD parses successfully, the ingredient lines are written into a local SwiftData index (`CachedIngredient`). Subsequent searches run a REST `search=` pass **and** a local ingredient pass and merge with this ranking: (1) REST title contains the query, (2) any other REST hit, (3) local-ingredient hit that REST missed. Duplicate recipes dedupe at the highest tier they appear in.
- **AC-12.2** Filter chips. Above the results, a horizontal chip row exposes: Category (default "All categories"; tap → menu of every WP category), Cook time (default "Any time"; tap → `≤ 15 min` / `≤ 30 min` / `≤ 60 min` / `1 hr+`), and a "Recently viewed" toggle. Filters are visible whether or not a query is active.
- **AC-12.3** Filters compose; changing one re-ranks the cached merge without a network round trip. Recipes with no category data or no parsed total-time are excluded by the corresponding chip (a MISS), so filter contracts can't be violated by missing metadata.
- **AC-12.4** Recent searches persist. The last `RecentSearches.maxEntries` (10) successful queries are stored in UserDefaults (`dod.recentSearchesV1`), case-insensitively deduped and trimmed. In the idle empty state the user sees a "Recent" header + tappable chips; a separate "Try" header lists the top-5 categories by recipe count as one-tap suggestions. Tapping a recent chip re-runs the search through the standard debounce path.
- **AC-12.5** Local search performance. The local ingredient pass for a typical cache (≤ 100 unsaved recipes per AC-1.6) returns within **200ms** on iPhone 13 baseline. Implementation note: a SwiftData `#Predicate` substring fetch against ~1000 normalized rows; no in-memory full-table scan.
- **AC-12.6** Telemetry contract unchanged. The recent-searches store keeps raw queries **local only**. Analytics continues to send only `StringHasher.sha256Hex(query)` per AC-3.6.

**Supersedes:** AC-3.2's "ingredient-body matching is **not required in v1**" remains the *spec-level* description of the REST contract; AC-12.1 specifies the locally-indexed augmentation.

### US-13 — Read + post a star rating
**As a** weekend cook,
**I want** to rate a recipe 1–5 stars and see what others rated it,
**so that** I can both contribute and triage the canon of recipes.

Added by the Phase 7 amendment (CL-21, 2026-05-24). Wires the app to WordPress Recipe Maker's existing rating system. A rating is technically a WP comment with `meta.wprm_comment_rating` set; from the user's perspective it's an independent star tap. Posting a rating may also leave a comment (US-14) but doesn't have to.

**Acceptance criteria:**
- **AC-13.1** Recipe detail header shows the WPRM rating summary (`/wp-recipe-maker/v1/rating/recipe/<id>`) as `<average star icon> · <count> ratings` when count ≥ 1. When count is 0, the summary is hidden — show only the inline 5-star input prompt "Rate this recipe."
- **AC-13.2** Tapping a star on the input fires the first-time guest-identity sheet if Keychain has no identity (US-15); otherwise immediately POSTs to `/wp-recipe-maker/v1/rating` with name + email from the Keychain identity, the star value, and the recipe id.
- **AC-13.3** After a successful POST, the input row collapses to "You rated this <stars>" with an "Edit" affordance; tapping Edit re-opens the star input and a subsequent POST overwrites the prior rating (WPRM dedupes by email).
- **AC-13.4** Network or server error: show inline "Couldn't save your rating — try again" with a retry button. Persisted rating state from Keychain so a stale rating shows on relaunch even before the network round-trip.
- **AC-13.5** Rating telemetry: new `AnalyticsEvent.recipeRated(recipeID:stars:)` event (constitution §9 amendment — see CL-21). No raw user text in the payload.

### US-14 — Read + post comments
**As a** weekend cook,
**I want** to read other cooks' comments and add my own,
**so that** I can share tips and learn from people who've made the recipe.

Added by the Phase 7 amendment (CL-21, 2026-05-24).

**Acceptance criteria:**
- **AC-14.1** Recipe detail has an expandable "Comments (<count>)" section below the instructions. Collapsed by default; tapping expands and lazy-loads `/wp/v2/comments?post=<id>&per_page=10&_embed=author`. Newest-first.
- **AC-14.2** Each comment row shows: author name, optional avatar (from `author_avatar_urls`), relative date ("3 days ago"), comment body (HTML-stripped via existing `HTMLSanitizer`), and the comment's star rating (if `meta.wprm_comment_rating > 0`) — small inline stars under the body.
- **AC-14.3** A "Write a comment" CTA at the bottom of the section opens a composer sheet: text field (1000-char max), optional star row (defaults to user's existing rating from US-13 if any), Submit button. Submit fires the guest-identity sheet (US-15) if needed, then POSTs to `/wp/v2/comments` with `post`, `author_name`, `author_email`, `content`, and (if a star was chosen) `meta: { wprm_comment_rating: <stars> }`.
- **AC-14.4** Post-submit feedback: if the response status is `approved`, the new comment appears immediately at the top of the list with a brief "Posted" snackbar. If status is `hold` (default — moderation queue), show a "Your comment is awaiting approval" snackbar and do NOT prepend it to the visible list (per AC-14.2 we only render `approved`). Either way the composer dismisses.
- **AC-14.5** Read path tolerates pagination: a "Load more" button at the bottom fetches the next page when `X-WP-TotalPages` says there are more.
- **AC-14.6** Offline read: comments cached locally on previous fetches show with an "(offline)" pill — see DODPersistence change (Wave-1 sub 3). Posting offline is queued (best-effort) and shown as "pending — will send when online" — Sub 3's responsibility.
- **AC-14.7** Comment telemetry: new `AnalyticsEvent.recipeCommentSubmitted(recipeID:moderated:Bool)`. No raw comment text. The `moderated` field is true when WP returns `hold`, false when `approved`. (Constitution §9 amendment — see CL-21.)

### US-15 — Guest identity (name + email, no account)
**As any** user about to post,
**I want** to tell the app my display name and email **once**,
**so that** I don't have to re-enter it on every comment or rating.

Added by the Phase 7 amendment (CL-21, 2026-05-24). The guest-identity model — name + email, Keychain-only, no password — is the constitutional substitute for accounts; see constitution §9.

**Acceptance criteria:**
- **AC-15.1** First tap to rate (US-13) or comment (US-14) presents a non-dismissible sheet asking for "Display name" (1–40 chars, no validation beyond non-empty) and "Email" (basic format validation: contains `@` and `.`, rejects obvious garbage). Both required to proceed.
- **AC-15.2** Submitting the sheet writes both values to the iOS Keychain under service `com.dutchovendaddy.DODApp.guest` (account: `display-name` and `email`). The sheet then dismisses and resumes the pending rate/post action automatically.
- **AC-15.3** A future Settings affordance (out of scope for v1; tracked as CL-22) will let users edit or clear their guest identity. For v1.0, identity can only be cleared by uninstalling the app.
- **AC-15.4** No identity field is ever sent to TelemetryDeck. Name and email travel ONLY to dutchovendaddy.com over HTTPS.
- **AC-15.5** Keychain access uses the modern `Security` framework via a small wrapper in `DODSupport` (Wave-1 sub 3 builds it). Reads are synchronous + cheap; writes throw on Keychain error.

**Integration shipped:** Wave-2 wired US-13/14/15 into `RecipeDetailView` (new `RecipeDetailRatingsSection` + view-model state + composition-root wiring) in commit `<filled in post-commit>` (T-220).

### US-8 — First-launch onboarding
**As a** Weekend Cook on first cold launch,
**I want** a brief welcome explaining what the app does,
**so that** I'm oriented before I land on the feed.

Added by consultant-pass amendment (CL-17, 2026-05-23). Reverses the earlier CL-7 "no onboarding" decision after the consultant pass argued that a single-screen sheet costs almost nothing and helps first-time users recognize the bookmark-save and search affordances before they need them. *(The original CL-17 wording said "heart-save"; CL-38 / T-380 (2026-05-24) flipped the glyph everywhere in the saved-recipes context, so the rationale now reads "bookmark-save" to stay in lock-step with AC-8.1's user-facing copy.)*

**Acceptance criteria:**
- **AC-8.1** On the first cold launch — gated by a single `UserDefaults` flag `dod.onboardingCompletedV1` — the app presents a single-screen modal sheet over the Feed. The sheet contains a friendly welcome line and exactly three bullets: "Browse the latest recipes from dutchovendaddy.com", "Search for what you're craving", and "Tap the bookmark to save any recipe for offline cooking". *Amended by CL-38 (T-380, 2026-05-24); the third bullet's "heart" wording is superseded so the onboarding affordance lines up with the post-T-380 glyph everywhere else. Original third bullet: ~~"Tap the heart to save any recipe for offline cooking"~~*
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

### US-11 — Live Activity for active Cook Mode timer
**As a** user actively cooking,
**I want** a Live Activity for the running Cook Mode timer,
**so that** I can leave the app to grab ingredients and come back at the buzzer without re-opening Cook Mode.

Added by consultant-pass amendment (2026-05-23, Tier 3). Builds on US-7 / AC-7.* — the Live Activity is a per-step companion to the inline ``CookTimer``, not a replacement. Constitution §2 was amended in the same pass to call out ActivityKit (iOS 16.1+) as the platform surface Cook Mode timers use.

**Acceptance criteria:**
- **AC-11.1** Given Cook Mode is on a step whose text parses to a duration (per `StepTimerParser`), when the user taps Start on the inline `CookTimer`, then a Live Activity is created with `recipeTitle`, `recipeID`, `totalSeconds`, and an initial `ContentState(remainingSeconds: totalSeconds, stepText: <current step text>, isPaused: false)`. The card appears on the Lock Screen and, on iPhone 14 Pro and later, in the Dynamic Island.
- **AC-11.2** While the timer is running, the Live Activity is updated every second with the new `remainingSeconds`; pausing the inline timer flips `isPaused` to true on the next update so the lock-screen UI can dim the progress arc and label the state.
- **AC-11.3** The Live Activity ends when (a) the countdown hits zero, (b) the user taps Reset, (c) the user starts a new step's timer (the previous activity is replaced, not stacked), or (d) Cook Mode itself is exited via the Done button or `endCookMode`.
- **AC-11.4** On hosts where ActivityKit isn't available (`iOS < 16.1`) or where the user has disabled Live Activities system-wide (`ActivityAuthorizationInfo().areActivitiesEnabled == false`), Cook Mode behaves exactly as it did pre-US-11 — the inline timer still runs, no Lock Screen card appears, and no errors surface to the user.

### US-16 — Tab bar refinement (Saved promoted, bookmark icon)
**As a** Returning Reader,
**I want** the "Saved" tab to live closer to the home tab and use a bookmark icon,
**so that** my saved recipes feel like a real shelf I return to (not a passing favorite) and are within easier thumb reach.

Added post-Phase 6 (2026-05-24). Aesthetic + ergonomic refinement; no new data, no new screens.

**Acceptance criteria:**
- **AC-16.1** Tab order on the bottom bar is **Recipes → Categories → Saved → Search** (Saved moves from position 4 to position 3; Search moves from position 3 to position 4). The `AppTab.allCases` order is the single source of truth and is what changes.
- **AC-16.2** The "Saved" tab uses SF Symbol `bookmark` when unselected and `bookmark.fill` when selected. Selection-aware variants follow the same pattern as existing system tabs (no custom asset).
- **AC-16.3** The in-recipe Save affordance (per `AC-4.7`) also uses `bookmark` / `bookmark.fill`, matching the Saved tab icon (AC-16.2) and every other saved-recipes surface. *Amended by CL-38 (T-380, 2026-05-24); supersedes the earlier carve-out from T-310 that kept the in-recipe heart in v1 — the "follow-up if it feels inconsistent" hedge in the original wording is the lineage being executed here. Original: ~~"The in-recipe Save affordance (`AC-4.7`, navigation-bar heart) is **unchanged in v1** — only the tab icon flips. Revisiting the in-recipe icon is a follow-up if it feels inconsistent in user testing; left out to keep this change reversible and surface a single decision at a time."~~*
- **AC-16.4** Telemetry: `AppTab.telemetryName` mapping is unchanged (`"saved"` stays `"saved"`); the change is purely visual + ordering, so existing screen-view event counts remain comparable across the change.
- **AC-16.5** L4 snapshot tests cover the tab bar in both light and dark appearance, iPhone 13 + iPad 12.9", with each tab selected. Baselines are updated as part of the implementing PR (intentional visual change).
- **AC-16.6** L3 UI smoke test asserts the third tab from the left opens Saved (was Search) and the fourth opens Search (was Saved), guarding against accidental re-ordering in a future refactor.

### US-17 — Home-screen widget for saved recipes
**As a** Returning Reader,
**I want** a home-screen widget that shows my saved recipes,
**so that** I can jump straight into one I've already bookmarked without opening the app and scrolling to the Saved tab.

Added post-Phase 6 (2026-05-24). Builds on the US-9 widget infrastructure (`WidgetSnapshotStore`, `WidgetDeepLinkParser`, `WidgetCard`, App Group container). This story adds a **second** widget alongside the existing today's-featured one; it does not replace it.

**Acceptance criteria:**
- **AC-17.1** A new home-screen widget kind, `SavedRecipesWidget`, is added to `DODAppWidgetBundle` alongside `FeaturedRecipeWidget`. The widget's display name is "Saved Recipes" and its description is "Your saved recipes, one tap from a cook."
- **AC-17.2** Supported sizes are `.systemSmall` (1 saved recipe) and `.systemMedium` (3 saved recipes). `.systemLarge` is **out of scope for v1** — revisit only if user testing surfaces demand.
- **AC-17.3** Widget content is sourced from a new snapshot file (`SavedRecipesWidgetSnapshot`) written to the App Group container by the host app whenever the saved set changes (observe `SavedStore` from `DODApp`). Snapshot carries the N most-recently-saved recipes (small=1, medium=3) with title + cached hero-image filename + canonical URL + recipe ID + saved-at timestamp.
- **AC-17.4** Tapping a recipe row in the widget opens its detail via the existing `dod://recipe/<id>` deep link (US-9 / `WidgetDeepLinkParser`). Tapping the widget chrome (outside any recipe row) opens the Saved tab via a new `dod://saved` deep link.
- **AC-17.5** Empty state: when no recipes are saved, the widget renders a placeholder ("Save a recipe to see it here") that tap-targets to the Saved tab (`dod://saved`). The widget never crashes or shows broken images for missing data.
- **AC-17.6** Timeline: the widget reloads at most once every 15 minutes from snapshot changes; the host app forces a reload via `WidgetCenter.shared.reloadTimelines(ofKind:)` whenever `SavedStore` writes or removes a recipe. No network calls from the widget extension itself.
- **AC-17.7** L4 snapshot tests cover empty / 1-saved / 3-saved states on both small + medium sizes, both light + dark appearances. Baselines committed.
- **AC-17.8** L1 unit tests cover: snapshot encode/decode round-trip, max-entries cap (small=1 / medium=3), version-mismatch rejection, and the new `dod://saved` deep-link parse case. Existing `WidgetDeepLinkParserTests` is extended; new `SavedRecipesWidgetSnapshotTests` lives next to the existing `WidgetSnapshotTests`.
- **AC-17.9** Telemetry: a new event `widgetOpened(kind: "saved" | "featured", recipeID: Int?)` replaces the implicit "widget deep link consumed" log. Constitution §9 allowlist updated in the implementing PR. Existing today's-featured tap continues to deep-link the same way; only the analytics shape generalizes.

### US-18 — Light/dark mode appearance polish
**As any** user,
**I want** every surface in the app to look intentional in both light and dark mode at every Dynamic Type size,
**so that** the app feels finished regardless of my system appearance.

Added post-Phase 6 (2026-05-24). Constitution §7 already mandates WCAG AA contrast in both modes — this story scopes the **audit + targeted fixes** to land the mandate everywhere it isn't already enforced by an existing snapshot test.

**Acceptance criteria:**
- **AC-18.1** Every top-level screen from US-1 through US-15 (Feed, Categories list, Category detail, Search, Recipe detail, Saved, Cook Mode, Onboarding, plus the comments + ratings section added by US-13/14/15) has L4 snapshot coverage in **both** light and dark appearances on iPhone 13 baseline. Gaps surfaced by the audit are filled by the implementing PR before any visual change is made (so the diff is provable, not opinion).
- **AC-18.2** Every reusable component in `DODDesignSystem/Components/` has L4 snapshot coverage in both appearances at default + AX5 Dynamic Type sizes. Same rule: existing gaps filled first, fixes proven by the diff.
- **AC-18.3** Audit checklist is captured in a new `specs/dod-ios-app/appearance-audit.md` (sibling to `accessibility-audit.md` and `performance-audit.md`). Each surface + component row records: light pass/fail, dark pass/fail, notes on any fix applied, baseline snapshot reference.
- **AC-18.4** Any contrast failure (WCAG AA, computed against the actual rendered tokens — not against the design system's stated values) is resolved either by adjusting the token in `DODDesignSystem.Colors` or by overriding at the offending site with a documented reason. No silent overrides.
- **AC-18.5** Reduce-Transparency and Reduce-Motion respected in both appearances (already required by constitution §7; the audit verifies it).
- **AC-18.6** The audit is allowed to surface *no* code changes — a clean audit closes the story. The deliverable is the audit document plus any fixes the audit prompted, not a guaranteed list of fixes.

### US-19 — Categories tab visual modernization
**As a** Recipe Hunter,
**I want** the Categories tab to feel like a current-iOS surface and to let me jump to a category by name,
**so that** scanning ~30+ categories doesn't read like a 2018 dictionary and I can find "Soups" without scrolling.

Added post-Phase 8 (2026-05-24). The Categories tab (US-2) was untouched by the CC-9 visual-density pass — that work only re-laid the four *grid* surfaces. The categories list still uses `.plain` style with a hand-rolled chevron + count `HStack`, which now reads stale next to the modernized Feed / Search / Saved. This story is a **Categories-only layout pass** that swaps in iOS-stock containers; it touches no design tokens and leaves the underlying data contract (US-2) intact.

**Acceptance criteria:**
- **AC-19.1** The Categories list uses SwiftUI's `.insetGrouped` list style so rows render inside a system-grouped card with iOS-standard rounded corners, inset, and separators — replacing the current `.plain` flat-list look. Each row is a `NavigationLink`-shaped cell with the system disclosure indicator instead of the hand-rolled `Image(systemName: "chevron.right")` in the existing `HStack`.
- **AC-19.2** Each row displays the category name on the leading side and the recipe count on the trailing side rendered as a `Text` in `DODColor.labelSecondary` (the system "value" treatment), with the disclosure chevron after it. No new design-system tokens; the visual ramp is built from the existing `DODType` / `DODColor` / `DODSpacing` set per CL-31 / CL-32.
- **AC-19.3** A native `.searchable` field is added to the Categories list, scoped to the list (placement `.navigationBarDrawer(displayMode: .automatic)` — the iOS standard). Filtering matches `category.name` case-insensitively; clearing the field restores the full list. The filter is purely client-side over the already-loaded `categories` array — no new network call, no view-model state machine beyond a `@State searchText`.
- **AC-19.4** US-2's existing acceptance criteria (AC-2.1 alphabetical order, AC-2.2 name + count, AC-2.3 tap → category recipes, AC-2.4 zero-count hidden, AC-2.5 error state with Retry) are **not regressed**. The implementing PR's tests pin each of AC-2.1..AC-2.5 against the new layout. The Categories *recipes* sub-screen (`CategoryRecipesView`, AC-2.3) is out of scope for this story — only the list of categories themselves is restyled.
- **AC-19.5** L4 snapshot coverage exists for the new layout on iPhone 13 baseline + iPad 12.9" in both light and dark appearances, at default Dynamic Type. The four existing `CategoryListViewSnapshotTests` baselines (light/dark × default/AX5 on iPhone 13) are re-recorded as part of this PR; new iPad-12.9" baselines (light + dark, default Dynamic Type) are added. AX5 on iPad is not added — list rows don't visually differ from iPhone at AX5 in a way the existing iPhone AX5 baseline doesn't already cover.
- **AC-19.6** Accessibility per constitution §7 / CC-1: the existing `.accessibilityLabel("\(category.name), \(category.count) recipes")` per-row label is preserved; the new search field has a default `.searchable` VoiceOver label ("Search"); the empty result state when no categories match the typed query shows an inline secondary-label "No categories match '<query>'" message (no full `EmptyState` takeover — the field stays visible).

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
  - **REG-11 (US-11)**: Cook Mode Live Activity lifecycle is fully exercised by the `CookModeViewModel` unit suite — start, end, replace-on-new-timer, no-op on tick when no activity, and end-on-cook-mode-exit are each pinned by a named test in `CookModeViewModelTests`. The lock-screen and Dynamic Island compact views are pinned by `CookLiveActivitySnapshotTests`. Failure mode: the cook would lose track of the buzzer the moment the screen dimmed and would either over-cook or have to keep the app foregrounded for the full duration.
  - **REG-12 (US-12)**: ingredient index round-trip, merger rank, and filter-composition logic stay correct as Search v2 evolves. Locked by `DODPersistenceTests.IngredientIndexTests` (write-on-mergeDetail, substring match, case-insensitive, short-query guard, re-merge replaces rows), `DODPersistenceTests.SearchFilterInputsTests` (category / total-time / recently-viewed accessors), `DODFeatureSearchTests.SearchResultMergerTests` (title > excerpt > local-only tier ordering and dedupe), `DODFeatureSearchTests.SearchFiltersTests` (each chip + composed), `DODFeatureSearchTests.RecentSearchesTests` (LRU dedupe + trim + clear), and `DODFeatureSearchTests` view-model coverage of `filterChipNarrowsResultsWithoutNetworkRoundTrip`, `recentSearchesPersistAcrossViewModelInstances`, and `offlineWithLocalIngredientHitsStillShowsResults`.
  - **REG-13 (US-13)**: WPRM rating round-trip. Locked by `DODNetworkingTests.WPRMRatingsClientTests` (summary read fixture + post body shape) and `DODFeatureRecipeDetailTests.RatingViewModelTests` (state machine after successful + failed post).
  - **REG-14 (US-14)**: WP comment list pagination + post payload + `hold` status handling. Locked by `DODNetworkingTests.WPCommentsClientTests` and `DODFeatureRecipeDetailTests.CommentsViewModelTests`.
  - **REG-15 (US-15)**: Keychain round-trip for the guest identity. Locked by `DODSupportTests.GuestIdentityStoreTests` (write → read → overwrite → clear). Note that the test uses a Keychain access group scoped to the test bundle so it doesn't leak into the device keychain.

## Clarifications

Phase 2 is closed. See [`clarifications.md`](clarifications.md) for the resolution of all 10 clarification items and the rationale behind each. Notable outcomes baked into the spec above:

- Hybrid fetch strategy: WP REST for lists, post-page JSON-LD for recipe details (CL-1, AC-4.11).
- Per-page = 20 (CL-2); categories only, no tags (CL-3); share URL = `post.link` (CL-4).
- Saves stay device-local in v1; iCloud sync = v2 (CL-5).
- iPad hero image up to 2048px from `media_details.sizes`; lists use `medium_large` (CL-6).
- No onboarding (CL-7); branding follows the blog, palette tokenized in `plan.md` (CL-8).
- Posts with unparseable Recipe JSON-LD are hidden from lists after first failure (CL-9, AC-1.7).
- Non-recipe-post handling deferred to a Phase 3 post-mix audit (CL-10).
