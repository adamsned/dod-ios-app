# Backlog — Dutch Oven Daddy iOS App

Informal capture for new feature ideas that haven't yet been broken
down into spec-driven work items. Anything goes here in any format —
one-liners, screenshots-by-link, half-formed thoughts, links to App
Store reviews. The point is that ideas don't get lost between the
moment they occur and the moment they're ready to enter the
six-phase workflow.

## How an idea graduates from this file

1. Drop the idea in the "Ideas" section below in any format.
2. When the idea is ripe for real work:
   - Add a clarification entry to [`clarifications.md`](clarifications.md)
     if it touches an open spec question.
   - Add a user story + acceptance criteria to [`spec.md`](spec.md)
     under a new US-NN heading.
   - Break it into PR-sized tasks in [`tasks.md`](tasks.md) with
     fresh T-NNN ids in a new cluster.
3. Once it's tracked in `tasks.md`, remove the entry here so this
   file is a true backlog (not a duplicate of the structured spec).

## Ideas

<!--
Format suggestion (not enforced):
- **Short title** — one or two sentences of context. Optionally:
  - Who asked / where the idea came from
  - Rough size guess (S/M/L)
  - Any links to mocks, screenshots, App Store reviews, etc.
-->

> Originally captured by @spencer0706 in `features.md` (commits `4601d12`
> + `21952f2`, pruned 2026-05-24 of items already shipped: Live Activities
> `2190f27`, app icon `1b8e027`, today's-featured widget `e0aebc6`). Moved
> here when the file relocated under `specs/dod-ios-app/`.

_All six 2026-05-24 captures have graduated to spec-driven work and
shipped. See "Recently graduated" below for the trail._

### Captured 2026-05-29 (round 9, @adamsned) — TestFlight 1.0 (2) install feedback

Dad's first real-device feedback after installing build `1.0 (2)` on `nadams-iphone` via TestFlight this morning (~07:50 MST). Captured here while using the app naturally; expect more entries as he keeps cooking with it.

#### Search is too strict — "nachos" doesn't find "Cast Iron Skillet Nachos"

**Real bug, blocks a user finding a recipe they know exists in the catalog.** Repro:

1. Open the app → Search tab
2. Type `nachos`
3. Expected: `Cast Iron Skillet Nachos` appears in results
4. Actual: result set does not include it (other recipes may or may not appear)

The recipe is published, indexed by the live blog, and findable via the WordPress site's own search. Something in the iOS app's search pipeline is filtering it out.

**Where to look — root-cause hypotheses worth checking in order:**

1. **WP REST `?search=` query semantics changed** — `WPRestClient+Posts.swift:32` calls `GET /wp-json/wp/v2/posts?search=<query>&_embed=wp:featuredmedia&page=1&per_page=20`. Recent WordPress versions (6.4+) layered a relevance-scoring pass on top of the underlying `WP_Query` `s=` LIKE match; the relevance pass can demote a post if it has fewer search-keyword occurrences than another match in the same set. If "Cast Iron Skillet Nachos" gets pushed to page 2 and we only fetch page 1, the user perceives it as missing.
2. **`per_page: 20` cap** — DOD's default page size truncates result sets that the site's own search shows in a single scroll. Bumping to 50 or implementing infinite-scroll in Search results would close the gap.
3. **Stale `URLCache.shared` / Cloudflare edge cache** — REG-18 (graduated to T-510 / CL-50) traced an identical symptom on the home feed to a CDN serving day-old batches. The fix bypassed both caches for `WPRestClient.get(...)` reads. **Verify the bypass is still in place for the search path specifically** — the fix may have been list-only and not extended to search.
4. **WP categories filter intersection** — REG-17 (graduated to T-530 / CL-53) found that dropping `Post.categories` from the WP DTO mapping caused the category filter chip to exclude every fresh hit. The current Search filter chips ("Any time" / categories) may be intersecting against a missing-category field and silently dropping matches.
5. **Slug vs title fall-through** — `RecipeListItem.title` is parsed from the WP `post.title.rendered` HTML. If "Cast Iron Skillet Nachos" has special characters in the title (smart quotes, hyphens, en-dashes) the JSON-LD parse may surface a different display string than the search-match field. Worth a one-grep: `Recipe.title` vs `RecipeListItem.title` divergence.

**Confidence**: high that this is a multi-cause issue, not a single broken line. WP's REST search is a known-soft surface; expect to need a layered fix.

#### "Make search way better than what you have now"

Dad's framing — a clear signal that the bug above is the visible symptom of a broader "search doesn't feel native" complaint. The current Search tab does:

- 300ms debounce → WP REST `?search=` → 20-recipe list, sorted by WP's relevance + date
- Recent searches (US-29 / CL-46)
- Curated suggestion pills (US-29 / CL-49 / T-500)
- Category filter chips (US-29 + REG-17 fix)

Directions worth scoping before this graduates:

- **Fuzzy / typo-tolerant matching.** "nahcos" or "Nachos!" or "skillet nachos" should all find the recipe. WP REST is exact-substring-only; a client-side index over the cached recipe list (the user already has ~100 recipes cached from feed scrolling) would let us do Levenshtein-tolerant matching for the user's catalog.
- **Search local + remote in parallel.** When the user types, show cached matches instantly (sub-frame), then merge in remote results when they arrive. Offline becomes useful.
- **Ingredient-name search.** "ground beef" → recipes that USE ground beef, not just recipes with "ground beef" in the title. Requires JSON-LD ingredients to be indexed locally — already cached per US-13 / SchemaV2 `CachedIngredient` (T-074-ish). Big differentiator vs. the website.
- **Sort by true relevance, not date-tiebreak.** WP's default is `relevance` for `?search=` but ties resolve to `date desc`, which buries older-but-perfect-match recipes. Need to investigate whether the WP RESPONSE relevance scores are even returned in `WPDTO.Post` (probably not — would need `wp-json/wp/v2/search` instead of `posts`).
- **Highlight match terms in results.** Show "Cast Iron Skillet **Nachos**" with bold on the matched substring. Lifts the result card from a generic title to an explanation of why it matched.
- **"Did you mean..." suggestions** when results are sparse (< 3). Use a stem-based suggestion table sourced from the cached recipe titles.
- **Spotlight indexing** via `NSUserActivity` + Core Spotlight. Recipes become searchable from outside the app — type "nachos" in Home Screen pull-down and DOD recipes appear. Big iOS-native win, hard to replicate on the website.
- **Recent + recommended interleaving on empty state.** Today the empty Search state is curated pills; could also surface 3-4 of the user's recent searches' top results as quick re-entry tiles.
- **Auto-complete / suggestion as you type.** Inline suggestion below the search bar, debounced at 150ms (faster than the result-fetch debounce). Pulled from cached titles + WP REST `wp-json/wp/v2/search` (which is a different endpoint, specifically for search suggestions).

**Constraints to preserve**: query is hashed before going to TelemetryDeck (US-12 / CL-12 — "search query never leaves device in cleartext"). Any client-side index uses local `CachedRecipe` rows; no new network surface.

**Rough size guess**: **L** if all of the above lands together; **M** if it's just the bug fix + local-fuzzy + ingredient-search subset. Likely splits into 3-4 task IDs.

Likely produces a new US (search overhaul) + clarifications for: client-side fuzzy threshold; ingredient-search scope (title-substring or stem-tokenized); whether to query `wp-json/wp/v2/search` in addition to `?search=`; Spotlight scope (saved-only or all browsed); Recent-searches re-entry tile policy.

#### Cook Mode voice sounds robotic — want natural-sounding voices + male/female toggle in Settings

**Real-device complaint** from dad after triggering Voice Mode (US-40 / T-690) in Cook Mode. The current `AVSpeechSynthesizer` in `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/VoiceReader.swift` uses `AVSpeechSynthesisVoice(language: Locale.current.identifier)` per CL-79 — that resolves to Apple's **system default** voice, which is the basic-tier "Samantha" (en-US female) or equivalent. Basic-tier voices are concatenative TTS — they sound robotic by design and they were shipping in iOS since iOS 7.

**What needs to change:**

1. **Switch to a Personal Voice / Premium / Enhanced quality voice by default** when one is installed on-device. iOS 17 ships with the **Siri voices** (`com.apple.voice.compact.en-US.Samantha` → `com.apple.ttsbundle.siri_female_en-US_compact`) which sound dramatically more human. iOS 16+ exposes the **Neural** Personal Voice tier via `AVSpeechSynthesisVoice.speechVoices()` filtered on `voice.quality == .premium`. The premium voices are NOT downloaded by default but iOS prompts the user to download (~150 MB) the first time they're requested. Strategy: enumerate available voices, prefer `.premium` over `.enhanced` over `.default`, fall back gracefully if none of the higher tiers are installed.

2. **Settings → Voice section** with a picker. CL-89 already adds an "iCloud Sync" section to Settings (T-703, PR #72 open); the same SettingsView extension pattern works for Voice. The picker should expose at minimum:
   - A **gender** toggle (Female / Male) bound to a UserDefaults key like `dod.voice.preferredGenderV1`. Default Female (matches Apple's system default).
   - An **automatic / specific voice** mode. "Automatic" picks the best available voice matching the gender preference; "specific" lets the power user pick from `AVSpeechSynthesisVoice.speechVoices()` filtered to `Locale.current.language`. Display the quality tier (Default / Enhanced / Premium) next to each voice name so users understand the trade-off.
   - A **"Download more voices"** button that opens Settings → Accessibility → Spoken Content → Voices (deep-link via `UIApplication.openSettingsURLString` + the iOS 17.4 settings URL extension). Premium voices live there and require user-initiated install.

3. **Persist + apply across launches.** The preference reads at `VoiceReader` construction (composition root in `AppDependencies`), survives container recreation, and is `@Sendable`-clean since `AVSpeechSynthesisVoice` is value-typed.

**Open questions for the clarification entry:**

- Should "Male" map to a specific voice (`Aaron` / `Daniel`) or just "any voice whose `gender == .male`"? Apple's voice list isn't tagged with gender directly — we'd need a manual mapping for the common voices.
- How do we handle non-English locales? Spanish + French both have premium Siri voices; German + Japanese vary by iOS version. Probably "automatic by locale" is the right v1 default, with an explicit-voice picker as the escape hatch.
- Privacy: voice preference is local-only, never leaves device (consistent with US-40's no-network-roundtrip promise per CL-79). One new analytics event `voicePreferenceChanged(quality:gender:)` would track adoption — count only, no specific voice identifier (PII concern: voice ID could correlate to language-region demographics).
- Should the gender toggle be a sub-setting of an existing "Voice Mode" toggle, or a top-level Settings entry? Probably top-level — discoverability matters more than visual hierarchy.

**Spec trace**: US-40 (Voice Mode) / CL-79 (current Locale.current default) — amendment territory. **Rough size**: **M** (~1 week — voice enumeration, picker UI, settings wiring, analytics event, 4 new tests). Constitution constraints intact (no third-party TTS dep — all `AVFoundation`).

#### Cast iron photo scanner → walks user through cleaning steps

**New feature request from dad**, observed from the real-device install. The pitch: open the camera, point at a piece of cast iron (rusty, seasoned, sticky, whatever), and the app diagnoses its condition + walks through cleaning + re-seasoning steps. Plays to DOD's brand — "Cast Iron Living" is on the icon — and turns the app from a recipe reader into a cast-iron care companion. Could be the single biggest "why this app exists" moment for a user who just inherited their grandfather's skillet.

**The architecture decision tree:**

| Approach | What it requires | Privacy / cost | Quality |
|---|---|---|---|
| **On-device Apple Foundation Models (iOS 26+)** | `FoundationModels` framework + a multi-modal vision request | Best privacy (no image leaves device), zero per-request cost, **iOS 26+ only** | Apple's image-classification quality is improving fast but cast-iron-specific knowledge is generic |
| **On-device Core ML model fine-tuned for cast iron** | Train a small CoreML model on a labeled dataset of cast iron states (good, rusty, sticky, layered seasoning, cracked) | Best privacy, requires the dataset (~500 labeled photos) + a training pass | Best targeted quality, but the dataset is the bottleneck |
| **Cloud LLM (Claude / GPT-4V)** with photo upload | Network round-trip + API key + image upload | **NEW privacy surface** (constitution §9 conflict — image data sent to a third party) + per-request cost | Highest immediate quality, no training needed |
| **Hybrid** — on-device vision detects "is this cast iron?" + opens an articles flow | Apple's built-in Vision framework (free, no model) + a static "cast iron care" article from dutchovendaddy.com | Best privacy, easiest to ship | Zero per-skillet diagnosis — just opens the same article every time. Probably the right **v1** if we ship anything. |

**v1 minimum path I'd recommend:** the hybrid. Add a Cast Iron Care tab/entry (or surface as a Settings → Tools menu item) that:

1. Opens the camera (requires new `NSCameraUsageDescription` Info.plist key — minor App Privacy questionnaire bump for "Camera, used to detect cast iron condition for cleaning guidance, not stored or transmitted").
2. Snaps a photo, runs `VNDetectRectanglesRequest` + a heuristic check that the photo contains a roughly-circular dark-toned object (cast iron geometry). This is just a "did the user point at something cast-iron-ish" check, not a quality grade.
3. Routes to a single curated **"How to Clean and Restore Cast Iron"** article hosted on dutchovendaddy.com (dad writes / publishes this). The article walks through the 5 condition states (good, soapy/sticky, rusty, cracked, never-seasoned) with photos and steps for each.

Total user value: the app opens the right page for them, with a moment-of-truth camera interaction that feels native. Cost: one new tab/menu item, one new article on the WordPress side (dad's scope), one Info.plist key, zero ML dependencies. **Punt the actual photo-→-state classification to v1.1** when we either have the labeled dataset or iOS 26 minimum supports the Foundation Models path.

**Open questions for clarification:**

- **Where does the entry point live?** A new tab eats the bottom-bar slot (US-37 / CL-65); a Settings menu item under "Tools" is discoverable but lower-traffic. A discovery card on the Saved tab ("Got a cast iron? Try the scanner") might thread the needle.
- **What happens when there's no internet?** Offline → "we'll show you when you reconnect," or just open the locally-cached article body (if T-640's article cache covers it). Probably the latter.
- **Photo permission flow.** First-launch of the scanner requests camera permission; deny → snackbar with a Settings deep-link explaining why we need it. Constitution §9 implications: zero — we never upload the photo for v1.
- **Constitution conflict on the v2 cloud-LLM path.** If we ever move from the hybrid to the cloud-LLM path, that's a §9 amendment (new third party + new data category in App Privacy + new constitution §3 dep). Capture that explicitly in the clarification so the future graduation has the constraint visible.

**Rough size**: **M** for v1 hybrid (~1.5 weeks: camera permission, scanner view, Vision rect detection, article deep-link, + the cleaning article on WordPress). **XL** for the on-device CoreML classifier path (training dataset + model + integration: months). **Owner check before any code lands** because the cloud-LLM variant is constitution-amendment territory.

#### Comments are broken on the installed TestFlight build — needs investigation + fix

**Real bug, real-device.** Dad confirmed comments don't work on TestFlight 1.0 (2). US-14 / T-650 shipped the comment-write path via `Packages/DODNetworking/Sources/DODNetworking/WPCommentsClient.swift` → `POST https://www.dutchovendaddy.com/wp-json/wp/v2/comments`. Something between the binary on the phone and the WordPress endpoint is broken.

**Where to look — priority-ordered diagnosis:**

1. **Composer flow opens but post tap silently fails.** Check the snackbar / error toast path in `CommentComposerViewModel` — if the WP server returns 401 / 403 / 422 and the error message gets swallowed, the user sees "tap → nothing happens." Hypothesis: the `WPClientError.unexpectedStatus(code:)` mapping reaches the view model but the view model's error toast doesn't surface it. Test path: open Settings → Network → Mobile Data, attempt a comment, watch for the "comment posted" snackbar that should fire on success per AC-14.4.
2. **WordPress moderation rejected the comment as spam.** Per CL-21 we required the WP "comment author must fill out name + email" setting + the moderation queue. If the moderation queue silently auto-trashes (Akismet aggressive setting + new install + low-reputation IP) the user perceives "I posted and it never appeared." Check WP admin → Comments → Spam / Trash for the test posts.
3. **WP user-agent or CORS reject from a new bundle ID.** The TestFlight build runs as `com.dutchovendaddy.DODApp` with a different user-agent than the simulator (the simulator gets `DODApp/1.0.0` while the device may carry the codesigned bundle's `CFBundleVersion` differently). If the WP install has a security plugin (Wordfence, etc.) that rate-limits or blocks unknown UAs, the POST returns 403 before reaching wp-json.
4. **Keychain guest-identity not migrating from device-storage policy.** `GuestIdentityStore.swift` writes to the iOS Keychain. On a fresh TestFlight install, the Keychain entry doesn't exist; the composer should prompt for name + email per US-15. If the prompt is skipped (e.g., a non-nil empty-string default), the WP server receives an anonymous-comment POST without `author_email` → 400 invalid params.
5. **App Transport Security (ATS) blocking the POST.** Production builds have stricter ATS than Debug — if the WP endpoint is HTTP-redirected anywhere in the chain (unlikely given the cert, but possible if Cloudflare's WAF rule does a 30x → HTTP shim), ATS blocks the request.

**Repro plan** (the entry doesn't graduate until the cause is pinned):

- Foreground the TestFlight build on dad's phone with Console.app attached
- Filter logs to subsystem `com.dutchovendaddy.DODApp`
- Attempt a comment post on any recipe with a known-working comment area
- Capture: the request URL fired, the response status code, the error path taken by `WPCommentsClient.postComment(...)` — these together pin which of (1)-(5) is the actual cause
- Cross-check WP-side: admin → Comments → All to see if the post landed in Pending / Spam / Trash / never arrived

**Constraints to preserve during the fix:**

- Constitution §6 L1 + L2: any regression has to be expressed as a failing test before the fix lands
- US-14 / AC-14.2: comments are author-name + email + content only — no extra fields snuck into the POST
- US-14 / AC-14.4: success and failure paths each surface a distinct user-visible state — no silent fails
- L5 E2E never writes to the live blog (per the constitution constraint) — the regression test stays at L1 / L2 with `FakeWPHTTPClient`

**Rough size**: **S** if it's hypothesis (1) or (4) (single view-model or single Keychain wiring fix), **M** if it's (2) or (3) (server-side WordPress configuration in dad's scope), **rare-but-possible XL** if it's a CFBundleVersion-driven cert-pinning issue that only manifests on signed builds (would need a code-signing-aware test surface, which we don't currently have).

**Graduates as a regression** (REG-NN) — likely the same path as REG-T-360 / REG-18 / REG-19 / REG-20, not a new user story. Spec trace stays under US-14.

#### Site ↔ app design coordination — match dutchovendaddy.com so the two surfaces feel seamless

**Feature request from @adamsned**, after observing the live site and the TestFlight 1.0 (2) build side by side. The current app's design language is iOS-native correct but visually diverges from the blog in seven measurable ways. Closing the gap is a contained DesignSystem-only change — no new feature code, no platform constraint, no third-party deps.

**The seven gaps observed against the live site (homepage + `/dutch-oven-recipes/`):**

| # | Gap | dutchovendaddy.com | App today |
|---|---|---|---|
| 1 | Primary backdrop color | Pure white `#FFFFFF` | Warm cream `#F9F6EF` |
| 2 | Card chrome on grids | None — photo + title only, no border, no shadow | Rounded `surfaceElevated` card with corner clip |
| 3 | Hero photo aspect | **3:4 portrait** (720×960) | Landscape ~16:9 (140pt fixed height + aspect-fill) |
| 4 | Time chip on cards | Absent | Cast-iron-brown capsule top-right |
| 5 | Excerpt under title | Absent | Two-line caption |
| 6 | Numbered "Popular" badge | Burnt-orange filled circles (1, 2, 3, 4) on the rail | Absent |
| 7 | Brand mark in-nav | Circular dark-brown DOD badge as the masthead | Text nav title only |

**Seven proposed moves to close them**, in graduation-ready spec language:

1. **Surface tier reshuffle** — `Surface` flips from `#F9F6EF` to `#FFFFFF`; `SurfaceElevated` collapses (cards no longer "lift"); a new `SurfaceWarm` (`#FAF6EE`) inherits the cream role specifically for the Saved tab + empty states + Cook Mode background. `CreamSubtle` renames to `SurfaceDivider` so its role (thin section dividers, sticky-header tint) is explicit.
2. **Drop card chrome on Feed + Categories** — magazine-grid variant of `RecipeCard` removes the elevated fill, corner clip, and shadow. Adds 8pt inter-card margin to replace the visual boundary the corners provided. `RecipeCard.ListRow` stays as-is for Search results + Saved (different mode, different rules).
3. **Switch the hero to 3:4 portrait, full-bleed** — `heroSection.frame(height: 140pt).aspectRatio(.fill)` becomes `.aspectRatio(3/4, contentMode: .fit)`. At iPhone 17 Pro Max (430pt) / 2 columns the hero is ~210×280pt; at iPad 13" / 3 columns it's ~325×433pt. Same crop, same composition as the site — no "wait, did I lose the picture?" moment when toggling between Safari and the app.
4. **Nav masthead = circular DOD logo** — reuse `App/AppIcon.icon/Assets/DOD Master.png` at 32pt circular in the toolbar leading position. Tap = scroll-to-top (iOS convention) but with the brand mark visible. Replaces the `"Recipes & Articles"` text title on the Feed tab.
5. **`DODBadge.Numbered`** — new component, 28pt circle filled `DODColor.burntOrange` (`#C56A24`), 16pt SF Rounded semibold white numeral, drop shadow y=2 blur=4 opacity=0.15, positioned bottom-left of the hero at 8pt inset. Applied only to editorially-curated "Featured" or "Top 5 This Week" rails — NOT every card.
6. **Demote time chip + excerpt to a peek-state** — primary gallery card carries photo + title only (centered, `.heading` weight, max 2 lines). Long-press peek surface keeps the time + excerpt + Save action. Recipe Detail screen continues to display the full metadata prominently. The Bravest Move — earns the seamlessness most because the site's read-quality comes from trusting the photography to do the work.
7. **Typography hierarchy alignment** — `displayLarge` + `displayMedium` shift `.semibold` → `.bold` to match the site's section-header weight. `heading` + `caption` adopt SF Rounded for a friendlier card-and-chip register. New `brand` token (`size: 22, design: .rounded, weight: .bold`) reserved for "DUTCH OVEN DADDY" wordmark moments (splash, About, share-sheet preview cards).

**Color tokens — after-state, ready to paste into Colors.xcassets:**

| Token | Light | Dark | Role change |
|---|---|---|---|
| `Surface` | `#FFFFFF` | `#1B140E` | Was `#F9F6EF / #42210B` — site-aligned white |
| `SurfaceElevated` | `#FFFFFF` | `#281F19` | Collapsed (no elevation on Feed) |
| `SurfaceWarm` | `#FAF6EE` | `#281F19` | **NEW** — cream's new home, Saved tab + warm states |
| `SurfaceDivider` | `#E6DECF` | `#3D2B1F` | Renamed from `CreamSubtle` |
| `Accent` / `BurntOrange` | `#C56A24` | `#C56A24` | Unchanged |
| `CastIronBrown` | `#3D2B1F` | `#3D2B1F` | Unchanged |
| `WarmGold` | `#D4A24C` | `#D4A24C` | Unchanged |
| `Label` | `#2C2C2C` | `#E6DECF` | Unchanged |
| `LabelSecondary` | `#6B6B6B` | `#A8A39A` | Unchanged |
| `LabelOnAccent` | `#FFFFFF` | `#FFFFFF` | **NEW** — text on `Accent` badges |

**Graduation plan** (constitution-amendment-free — no third-party deps, no new privacy surface, no platform change):

| Phase | Scope | Size |
|---|---|---|
| **a — tokens** | Update `Colors.xcassets` + `Typography.swift` + `Spacing.swift`. Re-record every L4 snapshot baseline (every screen, every Dynamic Type size, light + dark + AX5) at the new tokens. Roughly 60-80 PNGs. | **S** (~3 days) |
| **b — `RecipeCard` magazine variant** | New gallery-grid `RecipeCard` style behind a `DODFeed.layoutVariant` flag. `RecipeCard.ListRow` unchanged. Land side-by-side options so the next TestFlight build can A/B them. Add a Settings → Layout toggle so power users (Spencer) can flip between. | **M** (~1 week) |
| **c — Nav masthead + `DODBadge.Numbered`** | Logo asset in nav-bar leading toolbar. New badge component. Apply badge to Feed's "Featured" / "This Week" rail (whichever ships first). | **S** (~3 days) |
| **d — Recipe Detail surface polish** | Recipe Detail picks up the surface change + uses the portrait hero pattern at top. Comments + ratings sections inherit the new surface tier. | **S** (~3 days) |

Total: ~2.5 weeks calendar. **Behind-the-flag per screen** so a regression on any individual surface reverts without backing out the token update.

**Open clarification questions before graduation:**

- **The brave Move #6** — does dad agree the time chip + excerpt come off the gallery card? Or do we keep them and just adopt the site's color + photo aspect changes? (The chip + excerpt are real utility — losing them costs the user a glance.) Recommended: ship Move #6 ONLY on the magazine variant and keep the dense variant unchanged, so the Settings toggle in Phase b decides.
- **Dark mode parity** — site is light-only. App's dark mode currently uses `#42210B` (warm dark brown) as `Surface`. Should dark mode get the same site-aligned `Surface` shift, or stay warmer to preserve the cooking-mode read-in-low-light affordance? Recommended: keep dark mode warm; the site doesn't have a dark mode to coordinate against.
- **iPad treatment** — site is responsive but Web. iPad's `NavigationSplitView` sidebar inherits the surface change; the detail pane picks up the portrait hero. Anything specific to iPad worth pinning before Phase b?
- **A/B duration** — does the layout flag live on for v1.x as a permanent setting, or does it sunset after the magazine variant proves out in TestFlight? Recommended: ship as a permanent Settings → Layout option so users with strong format preferences keep their choice.

**Spec trace**: produces a new US (design coordination — site/app brand parity) + clarifications covering each of the 4 questions above. Likely splits into 4 phase IDs (T-NNNa..d above). **Size: M-L total** depending on how aggressively Move #6 lands.

### Captured 2026-05-28 (notification trigger — PAUSED pending @adamsned + WordPress)

- **Real-time "new post" notification trigger (the production signal behind US-42).**
  T-631/T-632 shipped the full **local**-notification plumbing: type-aware copy
  (recipe vs article), toggle gating, foreground banner, and tap-to-open that
  **fetches the post on cache-miss** and routes recipe→detail / article→article
  view (T-632 / REG-20). What's missing is the *trigger* — the app has no signal
  for "a new post was published." Spencer wants notifications to fire **when a
  new recipe or article actually drops**, which is genuinely impossible without
  a server-side push; this is **dad's call** since he controls the WordPress
  install. Options laid out for the dad conversation:

  | Approach | WordPress / backend side (dad) | iOS side remaining (us) | Notes |
  |---|---|---|---|
  | **OneSignal** (lowest effort) | Install OneSignal WP plugin + paste an APNs auth key; it fires a push on `publish_post` and stores device tokens on their servers (free tier) | Add the OneSignal iOS SDK | **New dependency → needs constitution §3 sign-off.** Fastest path to "exactly when it drops." |
  | **Custom webhook → APNs** | A `publish_post` hook POSTs to a small service that holds device tokens + sends APNs | `registerForRemoteNotifications`, POST the device token to that service, add `aps-environment` entitlement (dad's paid account enables it) | No new iOS dependency, but dad maintains a service. |
  | **Background-refresh polling** (no WordPress) | nothing | `BGAppRefreshTask` that polls the WP feed for a newer top-of-feed post id than last-seen and fires a local notification | **NOT instant** — fires within iOS's background window (~15-60 min). **Conflicts with NFR-3** ("no background fetch in v1") → needs a constitution amendment. Fallback if dad doesn't want to touch WordPress. |

  **iOS readiness:** display + copy + tap-routing are done (T-631/T-632). For the
  push options the only iOS additions are remote-notification registration + a
  device-token handoff; the deep-link routing a push would carry already works.
  **Do not graduate** until dad picks an approach (it determines whether we add a
  dependency, a backend, or amend NFR-3). Size: **S** on the iOS side once the
  approach is chosen; the WordPress/backend side is dad's scope.

### Captured 2026-05-24 (post-Phase-8 round 2, @spencer0706)

_(empty — all items graduated; see "Recently graduated" below.)_

### Captured 2026-05-27 (round 8, @spencer0706) — Post-T-640 regression bundle + new feature parallels

Round-8 captures landed after round-7 PRs (T-620 / T-630 / T-640 / T-650 / T-590 / T-580 / T-610) shipped to `main`. Spencer + dad split the work into four parallel branches: T-660 (this entry — tab-bar truncation), T-670 (phantom searches), T-680 (Shopping List — graduated round-3 dad item), T-690 (Voice Mode — graduated round-3 dad item).

#### Tab-bar truncation after T-640 rename

_(Graduated 2026-05-27 as T-660 / CL-65 — amendment to existing US-37 / AC-37.1, no new US needed. Bottom-tab `Label(...)` now reads `AppTab.tabLabel` ("Recipes" — short) while `FeedView.navigationTitle` keeps reading `AppTab.title` ("Recipes & Articles" — full). See CL-65 for the considered alternatives + the L4 snapshot baseline alignment notes.)_

#### Clear All shows 3 phantom searches in Recent ("Bourbon", "Sweet Potato", "Brisket")

_(Graduated 2026-05-27 as T-670 / CL-66 / REG-19 — amendment under existing US-29, no new US needed. Root cause was a recording-path leak (not a view-side leak): the round-7 `onCategoryTap` wiring routed curated "Try" pill taps through the same `recents.record(...)` path as user-typed queries, AND `clearRecentSearches()` did not cancel in-flight debounced searches that could re-record the just-cleared term. Fix: new `SearchViewModel.selectCuratedSuggestion(_:)` flips a `queryFromCuratedTap` flag that `performSearch()` honors; `clearRecentSearches()` now cancels `debounceTask` as a defensive belt; `SearchView.onCategoryTap` routes through the new method. `IdleSuggestionsView` was already correct (Recent section conditioned on `if !recents.isEmpty`). See CL-66 for the full root cause + the rejected-alternatives trail; REG-19 pins the empty-recents-after-Clear-All contract.)_

### Captured 2026-05-25 (round 3, @adamsned)

User has chosen to defer TestFlight until at least round 3 ships. These
three items each turn a feature the website *can't* easily replicate
into a reason the native app exists. Tier 1 from the consultant pass on
2026-05-25.

- ~~**Cooking Voice Mode** — hands-free recipe reading during Cook Mode.
  "Hey Siri, next step / repeat / pause / what was that?" Uses on-device
  `AVSpeechSynthesizer` so no network round-trip, no subscription cost,
  no privacy surface. Pairs with the existing Cook Mode + Live Activity
  infrastructure: the current step the Live Activity highlights is the
  same step Voice Mode reads aloud. Probably wants a `CL-` entry on
  whether to also wire up an App Intent (`ReadNextStepIntent`) so Siri
  can drive it without the app being foregrounded. Size: **M**
  (~2 weeks). The biggest differentiator we could ship vs. every other
  food-blog reader on the App Store.~~ _(Graduated 2026-05-27 as
  US-40 / CL-79 / T-690a + T-690b. v1 reads the current Cook Mode step
  aloud via on-device `AVSpeechSynthesizer` (system-default voice for
  `Locale.current` per CL-79), re-reads on every step change, ducks
  other audio via a `.playback` + `.duckOthers` audio session, exposes
  four Siri voice commands (next / previous / repeat / pause) via App
  Intents, and emits one `voiceModeToggled` adoption event — no spoken
  content ever leaves the device. Split into two tasks: **T-690a** ships
  the standalone, mock-tested `VoiceReader` core (the synthesizer wrapper
  + audio-session management + the `SpeechSynthesizing` test seam);
  **T-690b** wires it into `CookModeView` / `CookModeViewModel` (the
  toggle + the re-read-on-step-change driver), registers the four
  `RecipeAppIntents`, and adds the `voiceModeToggled` event + the
  constitution §9 allowlist amendment. Voice Mode is off-by-default and
  not persisted across cook sessions per CL-79 so the app never starts
  talking unexpectedly.)_

- ~~**Shopping list from saved recipes** — select N saved recipes →
  "Add to shopping list" → ingredients grouped by aisle (produce /
  pantry / dairy / meat / spices / other) with checkable items and an
  "I already have this" toggle per ingredient. Share-via-iMessage as the
  primary export (perfect for sending the list to a spouse on the way to
  the store). Pure local SwiftData; no WP backend involvement. The
  aisle classifier is the one open design question — could be a small
  static keyword map (good enough for v1), could escalate to a
  category-tagged ingredient dictionary later. Size: **M** (~1.5 weeks).
  Turns the recipe app you cook *from* into the grocery list you shop
  *from*. Massive utility loop.~~ _(Graduated 2026-05-27 as T-680 / CL-67–CL-78 / US-39 — see "Recently graduated" below. v1 ships the static keyword classifier per CL-67, single global list per CL-69, per-recipe rows per CL-70+CL-77, per-row session toggle per CL-71, `UIActivityViewController` plain-text share per CL-72, three entry surfaces per CL-73, new `ShoppingListItem` `@Model` + SchemaV4 per CL-74, two aisle-only analytics events per CL-75, and the canonical `EmptyState` reuse per CL-76. Three deferred-by-design items: location-based notifications (CL-68), multi-list lifecycle (CL-69), and pantry inventory (CL-71) — each with its own documented activation trigger.)_

_(Graduated — see "Recently graduated" below: US-31 / CL-52 / T-440
shipped the stepper + `FractionRenderer` + warning copy.)_

**Explicitly deferred from this round** (consultant Tier 2+ — capture
later if v1.x user reviews call for them): Universal Links to the
website, Recipe Collections ("Cookbooks"), Apple Watch + complications,
background app refresh, daily push notification, photo-with-comment.
Don't graduate these into spec work without a real user signal — they
either need a paired web-side effort (Universal Links) or have
non-trivial scope risk (Watch, Collections).

### Captured 2026-05-26 (round 7, @spencer0706) — Settings expansion, Recipes & Articles rename, view toggle, long-press menus, color refinement

Captured before Spencer headed out for the evening. **Not to be built tonight** — these are for the next session. Per Spencer's direction, the next session should also batch in the existing **Shopping List** (round 3, dad) and **Voice Mode** (round 3, dad) backlog items alongside these. Login + OAuth (round 6) stays paused — Spencer is still discussing the architecture with dad.

#### Settings page expansion

- ~~**Add more standard settings.**~~ Graduated 2026-05-27 as US-36 / CL-62 / T-630, with the Notifications row's behavior graduated 2026-05-28 as US-42 / CL-100 / T-631 (**local** notifications, not APNs). The audit-and-pick narrowed to five rows: Notifications (UI-only when T-630 shipped; T-631 wired it to on-device local notifications with recipe-vs-article type-aware copy + tap deep-linking, gated by the toggle), Appearance (Match System / Light / Dark — `.preferredColorScheme` on `RootView`), Default Share Format (link-only / link + recipe text — persisted now, consumer is a future task), Clear Cached Recipe Images (button → `RecipeStore.clearImageCache()` → snackbar with freed-MB count, pinned images preserved), and Share Anonymous Usage Data (toggle, default ON per constitution §9, `TelemetryDeckTransport` short-circuits when OFF). Cook Mode keep-screen-awake, accessibility shortcuts, and legal links were deliberately deferred — see CL-62 for the reasoning.

- **"About Ned Adams & Dutch Oven Daddy" — shorter paragraph + image.** The current placeholder paragraph in T-550's Settings → About row is too long for a phone screen. Replace with this exact copy:

  > Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!

  Also include the photo of Ned (the one Spencer attached in this round-7 capture — kitchen background, holding a black cast-iron dutch oven, blue shirt + brown leather apron). **Image-to-paragraph ratio should be appropriate** — the image is a portrait accent for the text, not a hero. Recommend ~120pt wide on iPhone, leading-aligned with the paragraph wrapping to its right (like a magazine sidebar layout) OR top-anchored above the paragraph if the wrap doesn't read well.

  **Asset prep:** Spencer attached the image to the conversation but Claude Code's attachment store wasn't reachable from Bash, so the binary wasn't saved to the repo automatically. The next agent that builds this should:
  1. Ask Spencer for the image again, OR
  2. Pull it from `https://www.dutchovendaddy.com/about-me/` (the existing About-Me page likely hosts the same photo)
  3. Save under `App/Assets.xcassets/AboutNed.imageset/` (or as a Markdown-rendered asset if About content is HTML-based)

  Size: **S** for the copy + asset wire-up. Supersedes T-552 (About Me fetch) since the copy is now embedded, not fetched — capture that supersession in the CL when this graduates.

#### New recipe-detail action

- ~~**Download for offline viewing button (`square.and.arrow.down`).** Adds a third nav-bar action next to Save (`bookmark`, AC-4.7) and Share (`AC-4.8`). Tap → download the recipe payload (text + ingredients + steps + hero image at full resolution) for on-device offline access. "Perfect for camping when you don't have access to internet." Semantically distinct from Save (which is "I want to remember this") — Download is "I want to use this without network." A saved recipe is auto-downloaded per AC-5.2; download alone is a save without the bookmarking. Spec question: do Download and Save share storage? Are they separate concepts in the UI? Probably yes-and-yes with a UX distinction. Size: **M** — backend reuse is straightforward, the UX question is what makes it medium.~~ **Graduated 2026-05-27 as US-35 / CL-61 / T-620.**

#### Recipes tab rename + content typing

_(Graduated 2026-05-27 as US-37 / CL-63 / T-640. Spec amends CL-9 + CL-10 + AC-1.7 + AC-4.11 — original wording struck through; lineage captured in CL-63.)_

#### Layout toggle

_(Graduated 2026-05-27 as US-38 / CL-64 / T-650. Icon-convention choice landed on Spencer's explicit direction — the button shows the CURRENT layout (`square.grid.2x2` in gallery, `list.bullet` in list), opposite of typical iOS "destination" convention. Layout choice persists via `@AppStorage("dod.recipeListLayout")` and the same persisted value drives both the Recipes & Articles tab and the Search tab. See CL-64 for the considered alternatives.)_

#### Long-press context menus

- ~~**Recipe/Article card long-press → "Save" with `bookmark.fill` icon.** Standard SwiftUI `.contextMenu` on the card. Tap menu item → save the recipe/article to the Saved tab (same code path as AC-5.1 tap-the-bookmark-on-detail flow). Works in both gallery and list view. Size: **S**.~~ **Graduated 2026-05-27 as US-34 / CL-60 / T-590.**

- ~~**Recent search long-press → "Clear" with `trash` icon, deletes only that term.**~~ Graduated → US-33 / CL-57 / T-580 as part of the Search-tab tweaks bundle.

#### Color refinements

- ~~**"Clear All" button in Search tab should match the gear-icon orange in Recipes tab.**~~ Graduated → US-33 / CL-57 / T-580 as part of the Search-tab tweaks bundle. Token: `DODColor.accent` (the gear icon inherits the app-level `.tint(DODColor.accent)` from `RootView.swift`).

- ~~**List cells + search bars: `#553724` in dark mode, `#FFFFFF` in light mode.**~~ — Graduated to CL-59 / T-610 as a further refinement of `SurfaceElevated` dark from `#5A3520` to `#553724` (Option A — single hex tweak; light stays `#FFFFFF`). Snapshot re-record remains T-571's deferred scope.

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| ~~Standard settings expansion~~ | ~~M~~ | Graduated → US-36 / CL-62 / T-630 (+ T-631 APNs follow-up) |
| About Ned copy + photo | S | Asset prep open question |
| Download button | M | Reuse cache, define UX distinction from Save |
| Recipes & Articles rename + article-rendering path | M | Amends CL-9 / AC-1.7 / AC-4.11 |
| ~~Gallery ↔ List view toggle~~ | ~~M~~ | Graduated → US-38 / CL-64 / T-650 |
| Card long-press → Save | S | SwiftUI `.contextMenu` |
| ~~Recent long-press → Clear~~ | ~~S~~ | Graduated → US-33 / CL-57 / T-580 |
| ~~Clear All orange color match~~ | ~~XS~~ | Graduated → US-33 / CL-57 / T-580 |
| ~~List-cell + search-bar color refinement~~ | ~~S–M~~ | Graduated → CL-59 / T-610 (Option A: refine `SurfaceElevated` dark `#5A3520` → `#553724`) |

**Next session also picks up these existing items per Spencer's batching note:**
- Round-3 dad: **Shopping List** (~1.5 weeks)
- Round-3 dad: **Voice Mode** (~2 weeks)

**Still paused (Spencer + dad architecture conversation in progress):**
- ~~Round-6 spencer: **Login + OAuth** (XL — requires constitution amendments §1/§3/§4/§9)~~ _(Graduated 2026-05-28 as T-700 / CL-86..CL-99 / US-41 — CloudKit private-DB sync replaces Spencer's OAuth framing; see Phase 15 amendments. CloudKit container `iCloud.com.dutchovendaddy.DODApp` + opt-in toggle in Settings → iCloud Sync. App works without iCloud sign-in per AC-41.1 / REG-26 (App Store 5.1.1(ii)); "account deletion" semantics via toggle-off or iCloud sign-out per AC-41.5 (App Store 5.1.1(v)). Constitution §1 / §3 / §4 / §9 amendments smaller than the OAuth variant would have required — no third-party dep (CloudKit.framework is Apple-provided per CL-93), no new App Privacy disclosure (per CL-94 — CloudKit data is the user's iCloud data, not "data we collect"). Google Play deferred as non-applicable per CL-98 — there is no Android target. See "Recently graduated" below for the implementation cluster.)_

### Captured 2026-05-26 (round 6, @spencer0706) — Search-tab cleanup + new recipe surfacing + design + login

Mix of small Search-tab polish, a real bug (new recipes not surfacing), a design-system overhaul, and one massive feature (login + OAuth) that needs a constitution amendment before any code lands.

#### Search-tab polish (5 small items, likely one PR)

_(All 5 items graduated as the **US-29 / CL-49 / T-500** bundle — see "Recently graduated" below.)_

#### Filter logic

_(Graduated — see "Recently graduated" below: T-530 / CL-53 / REG-17 traced the bug to the WP REST → domain → cache pipeline dropping `Post.categories`, so the category filter excluded every fresh REST hit and the AND with the Any-time chip yielded zero. Fixed by propagating `categoryIDs` through `RecipeListItem` and `RecipeStore.cache(listItem:)`.)_

#### New-recipe surfacing — real bug, not just a backlog idea

_(Graduated — see "Recently graduated" below: T-510 / CL-50 / REG-18 traced the bug to URLCache.shared + Cloudflare CDN serving stale page-1 batches, fixed by bypassing both caches inside `WPRestClient.get(...)`.)_

#### Design-system overhaul

_(Background/foreground color overhaul graduated — see "Recently graduated" below.)_

#### Major feature — needs constitution amendment before code

- ~~**Login + account system (Google + Apple + email).** Account icon in the Recipes tab's top-right nav corner; tap → login sheet with three options. Name + email persist across the app for save / comment / rate flows.~~ _(Graduated 2026-05-28 as T-700 / CL-86..CL-99 / US-41 — see "Recently graduated" below for the implementation cluster. **The OAuth framing is reversed**: there is no Account icon, no login sheet, no providers; the user's iCloud account is the sync identity per CloudKit private DB. CL-87 carries the full reversal trail and CL-98 documents the future-Android Google sign-in path that would re-introduce OAuth if/when constitution §2 is amended to add Android. The five constitutional conflicts Spencer flagged below remain accurate as the **original analysis**, but the CloudKit pivot makes the actual amendments dramatically smaller than the OAuth variant would have required — §3 adds Apple-provided `CloudKit.framework` (no third-party dep per CL-93), §4 adds a "Synced records" data-boundary category, §9 adds four closed-enum events without changing the App Privacy questionnaire (per CL-94, since CloudKit data is the user's iCloud data — not "data we collect"), §1 acknowledges a v2 sync model without changing "no accounts in v1," and CL-5's "iCloud sync deferred to v2" is explicitly reversed per CL-86.)_

  **Constitutional conflicts Spencer flagged in the original round-6 capture (kept as historical context — disposition per CL-86 / CL-87):**
  1. **§1 Product identity:** ~~today says "mostly read-only with two write surfaces." Login changes the app's identity considerably — it stops being anonymous.~~ _Partially preserved: the app is still anonymous to us (no account in our system) and just signed-in-to-iCloud, which is the user's relationship with Apple, not ours. §1 amended with a "v2 sync model" subsection, not a wholesale identity shift._
  2. **§4 Content source:** ~~"No auth required for reads in v1. Anonymous client." Would need to amend.~~ _Preserved unchanged. WP REST reads remain anonymous; only the user's own saves sync via CloudKit, captured by §4's new "Synced records" data-boundary category._
  3. **§9 Privacy & security:** ~~OAuth adds Google + Apple as third parties; the App Privacy questionnaire changes meaningfully (now collecting account credentials).~~ _Averted entirely. No third parties, App Privacy questionnaire unchanged per CL-94._
  4. **§3 Dependencies:** ~~would need `GoogleSignIn` SDK; `Sign in with Apple` uses system `AuthenticationServices` (no new dep). Both need plan-time approval.~~ _Averted entirely. CloudKit.framework is Apple-provided per CL-93._
  5. **CL-5 (iCloud sync deferred to v2):** ~~today says saved recipes are device-local. A real account opens server-side sync of saves + comments + ratings; the spec needs to decide whether login implies sync or whether they're still independent.~~ _Reversed per CL-86. CloudKit sync ships in v1.x; AC-5.7's "reinstall wipes saves" limitation is softened (with sync enabled, reinstall restores)._

  **Backend implications:** ~~dutchovendaddy.com's WordPress doesn't natively support OAuth account creation — adding it requires a WP plugin (e.g., MiniOrange, WPOAuth) or a side service. This is a paired web + iOS effort, not iOS-only.~~ _Averted entirely. No WP plugin, no side service. Per CL-86, CloudKit private DB is iOS-native + Apple-hosted + zero ops surface._

  Original size estimate: **XL** (~3-4 weeks for the iOS side alone; backend longer). _Actual size post-pivot: **M** (~1 week of CloudKit adapter wiring, per the Phase 15 cluster T-700..T-708 estimate of ~29 hours)._ ~~**Paused pending architecture conversation with dad before graduating.**~~ _Graduated 2026-05-28._

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| ~~1. Tag search "No recipes match"~~ | ~~S~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~2. "Clear All" recents button~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~3. `questionmark.circle` not `.folder`~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~4. Remove "All categories" button~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~5. "Try" suggestions fill search bar~~ | ~~S~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~6. "Any time" filter composes~~ | ~~M~~ | Graduated → REG-17 / CL-53 / T-530 |
| ~~7. Login + OAuth~~ | ~~XL~~ → M | Graduated → US-41 / CL-86..CL-99 / T-700..T-708 (CloudKit private DB, NOT OAuth; see CL-86 / CL-87) |
| ~~8. New recipes don't surface~~ | ~~M~~ | Graduated → REG-18 / CL-50 / T-510 |
| ~~9. Background/foreground color overhaul~~ | ~~M~~ | Graduated to US-30 / CL-51 / T-520 |

### Captured 2026-05-25 (round 5, @spencer0706) — widget fixes that didn't actually fix the bugs

After T-362 (PR #34, commit `0aa8633`) and T-394 (PR #37, commit `5f500c8`) merged
and Spencer rebuilt the simulator with both fixes, **both bugs still appear to be
present from the user's perspective.** Re-opening with new IDs so the next attempt
starts fresh instead of patching the same patches.

- **REG-T-362-v2 — Latest Recipe widget image still shows fork-and-knife.** T-362
  added a feed-side image prefetch through `RecipeStore.cacheImage(...)` to
  populate the App Group container (verified: 5 `.img` files appear after 20s).
  The bridge writes are confirmed working at the file-system level, but the
  widget still renders the placeholder in Spencer's testing. Possible gaps to
  investigate:
  1. Widget snapshot reads the filename but `AsyncImage` at the resolved
     `file://` URL fails silently (file permissions, sandbox boundary, URL
     malformation).
  2. Widget timeline cache holds the pre-T-362 snapshot for longer than
     expected; `WidgetCenter.shared.reloadAllTimelines()` may need to be called
     explicitly post-prefetch instead of waiting for the natural 15-min cap.
  3. The widget extension's filename → file-URL resolution path in
     `FeaturedRecipeWidgetEntryView` may have a bug introduced by T-362 that
     wasn't caught because the manual verification only checked file presence,
     not widget rendering on the home screen.
  Reproduce: fresh-install the app, add the Latest Recipe widget to the home
  screen, browse the Recipes tab for 20s, force-reload the widget (or wait the
  natural cap), confirm whether the widget shows a real recipe image.

- **REG-T-394-v2 — Tinted/Clear home-screen widget still has the readability bug.**
  T-394 added `widgetAccentedRenderingMode(.fullColor)` on the scrim + text
  overlay groups via PR #37 / commit `5f500c8`. The snapshot tests it re-recorded
  show legible text. But Spencer's real-home-screen test in Tinted mode still
  surfaces the white-on-white-ish problem. Possible gaps:
  1. The `.fullColor` opt-out is being applied at the wrong scope — needs to be
     on each `Image` / `LinearGradient` individually rather than on the VStack
     containing them.
  2. The widget's `containerBackground` strips even the `.fullColor`-marked
     children in `.accented` mode (iOS 18+ behavior may be more aggressive than
     documented).
  3. T-394's snapshot tests render the view in a test host that doesn't fully
     replicate the system Tinted rendering pipeline — the snapshot looks fine
     because the test environment isn't the real environment.
  Reproduce: install fresh build, add Latest Recipe widget, switch home screen
  to Tinted mode (long-press → Edit → tint → pick a bright color), confirm
  whether title is readable. Crucial: this is now the SECOND attempt at this fix
  (T-390 → T-394). The next attempt should NOT rely on snapshot tests as proof
  — it should require a real home-screen install + screenshot in Tinted mode
  before merging.

#### Lessons to bake into future widget-fix tasks

- **L4 snapshot tests don't replicate the real widget rendering pipeline.** Both
  REG-T-362-v2 and REG-T-394-v2 had snapshot tests that passed while the real
  widget on the real home screen stayed broken. Any future widget-bug fix should
  take a real screenshot from the installed widget on the home screen, not just
  from the test host.
- **The image bridge needs an end-to-end widget render verification, not just a
  file-presence check.** T-362's verification confirmed bytes hit the App Group
  directory; it never confirmed the widget read them and rendered them.
- **A "fix" that passes its own audit but the user still sees the bug means the
  audit's threshold was wrong.** T-390 → T-394 → REG-T-394-v2 is now a chain of
  this same failure mode. The next attempt at REG-T-394-v2 needs to define
  "fixed" as "Spencer (or dad) looks at the simulator and confirms the bug is
  gone" — not as "the snapshot test passes."

### Captured 2026-05-25 (round 4, @spencer0706)

Mix of new surfaces, polish, an L2 test addition, and two regression
reports against work that just shipped (items marked **REG-** in the
notes). Captured after using the post-round-2 build on iPhone 16 sim.

#### New surfaces / features

- ~~**Settings page**~~ — Graduated to US-32 / CL-56 / T-550 (skeleton),
  with T-551 (metric-units conversion) and T-552 (About Me WP REST fetch)
  as explicit Phase 10 follow-ups.

#### Polish

- **Categories tab brown.** The categories list cells + the
  `.searchable` field background in the Categories tab should pick up
  the same brown used by the recipe cards in the main Recipes tab
  (probably `DODColor.castIronBrown` per the existing palette). T-340
  picked iOS-stock `.insetGrouped` styling which uses the system grouped
  background; this would override to match the brand surface. Worth a
  CL on whether this should be a global `.scrollContentBackground`
  override or per-cell tinting — both have implications for dark mode
  legibility. Size: **S–M** depending on whether the brown gets applied
  cell-level or surface-level.

#### Tests

_(empty — the L2 new-recipe-surfacing test graduated to REG-16 / T-420;
see "Recently graduated" below.)_

#### Regression reports — work that just shipped but the user still sees broken

_(REG-T-360 graduated — see "Recently graduated" below.)_

_(REG-T-390 graduated — see "Recently graduated" below.)_

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| Settings page | L | Splits into multiple T-NNN at spec time |
| ~~Ratings layout cleanup~~ | ~~S~~ | Graduated → US-26 / CL-41/42 / T-410 |
| Categories tab brown | S–M | Needs CL on cell-vs-surface tinting |
| ~~Saved widget description~~ | ~~XS~~ | Graduated to US-25 / CL-40 / T-400 |
| ~~L2 new-recipe test~~ | ~~S~~ | Graduated to REG-16 / CL-43 / T-420 |
| ~~REG-T-360 widget image~~ | ~~M~~ | Graduated to CL-45 / T-362 |
| ~~REG-T-390 widget text~~ | ~~M~~ | Graduated to CL-48 / T-394 |

## Recently graduated

Items that left the backlog after going through Specify → Clarify → Plan →
Tasks → Implement. Kept here as a short audit trail; remove entries once
they're far enough in the rear-view mirror that the spec is the only
useful reference.

- **Swap "Search" and "Saved" tab positions** — became **US-16** /
  AC-16.1 / [T-310](tasks.md). Shipped in [#10](https://github.com/adamsned/dod-ios-app/pull/10).
- **Heart → bookmark on the Saved tab icon** — folded into the same
  US-16 / AC-16.2 / T-310. Shipped in [#10](https://github.com/adamsned/dod-ios-app/pull/10).
  In-recipe Save heart intentionally untouched per AC-16.3.
- **Saved-recipes home-screen widget** — became **US-17** (AC-17.1
  through AC-17.9) and the [T-320..T-323 cluster](tasks.md). Shipped
  across [#8](https://github.com/adamsned/dod-ios-app/pull/8) (snapshot infra),
  [#17](https://github.com/adamsned/dod-ios-app/pull/17) (extension + entry view),
  [#18](https://github.com/adamsned/dod-ios-app/pull/18) (host SavedStore wiring),
  [#19](https://github.com/adamsned/dod-ios-app/pull/19) (`widgetOpened` analytics).
- **Light/dark mode polish** — became **US-18** + [T-330](tasks.md)
  (audit) and the [T-331..T-334 follow-ups](tasks.md) the audit
  surfaced. Audit shipped in [#9](https://github.com/adamsned/dod-ios-app/pull/9);
  DesignSystem dark + AX5 baselines in [#14](https://github.com/adamsned/dod-ios-app/pull/14);
  top-level screen baselines in [#15](https://github.com/adamsned/dod-ios-app/pull/15).
  CookLiveActivity baselines (T-333) still in flight on
  [#11](https://github.com/adamsned/dod-ios-app/pull/11).
- **Categories tab — modernize visual language** — became **US-19**
  (AC-19.1 through AC-19.6) + [T-340](tasks.md), with the
  token-vs-layout decision captured in
  [CL-31](clarifications.md), the `.insetGrouped` choice in
  [CL-32](clarifications.md), and the `.searchable` add-in in
  [CL-33](clarifications.md). Layout-pass only — no `DODDesignSystem`
  token churn, no `CategoryRecipesView` change, US-2's
  AC-2.1..AC-2.5 explicitly pinned by AC-19.4. Shipped in
  [#22](https://github.com/adamsned/dod-ios-app/pull/22).
- **Search tab — `tag.fill` instead of folder icon on tags** — became
  **US-20** (AC-20.1 through AC-20.5) + [T-350](tasks.md), with the
  glyph-choice rationale (`tag.fill` over `tag` / `number` /
  `crop.rotate` / keeping `folder`) captured in
  [CL-34](clarifications.md). What the backlog called "tags" turned
  out to be WordPress *categories* in code (Search v1 surfaces only
  the category taxonomy per CL-3); the same `folder` glyph appears on
  both the `FilterChipRow.categoryChip` and the `IdleSuggestionsView`
  "Try" category-suggestion pills, and both swap to `tag.fill` in this
  PR. The `.noResults` `questionmark.folder` empty-state glyph is
  explicitly out of bounds per AC-20.3. Pure SF Symbol swap — no
  layout change, no token change, US-12's AC-12.1..AC-12.6 pinned by
  AC-20.5. Shipped in [#23](https://github.com/adamsned/dod-ios-app/pull/23).
- **"Today's Recipe" widget → rename + show real recipe image** —
  became **US-21** (AC-21.1 through AC-21.6) + [T-360](tasks.md), with
  the file-export image bridge decision (vs shared-SwiftData-container
  vs widget-side URLSession) captured in
  [CL-35](clarifications.md) and the display-name rename rationale in
  [CL-36](clarifications.md). T-360 builds the bridge + wires the
  featured widget; saved widget consumption is the
  [T-361](tasks.md) follow-up (same bridge, second consumer — clears
  T-322's open "Future work" note). Shipped in
  [#24](https://github.com/adamsned/dod-ios-app/pull/24).
- **Heart → bookmark everywhere in the saved-recipes context** —
  became [CL-38](clarifications.md) + amended `AC-4.7`, `AC-5.1`,
  `AC-5.8`, `AC-8.1`, `AC-16.3` (the last via explicit reversal of
  T-310's carve-out) + [T-380](tasks.md). Extends CL-24's bookmark
  decision into every saved-recipes surface: in-recipe nav-bar Save
  button, sticky floating Save button, Saved tab empty state, Save
  snackbar wording, onboarding bullet copy, `OpenSavedRecipesIntent`
  Siri shortcut glyph. Wire-format `widgetOpened` `kind: .saved` and
  US-11 Live Activity glyphs explicitly out of scope per CL-38.
- **Lock-screen widget for "Latest Recipe" (rectangular)** — became
  **US-22** (AC-22.1 through AC-22.5) + [T-370](tasks.md), with the
  `.accessoryRectangular`-only family decision (and the reasons
  `.accessoryCircular` / `.accessoryInline` are out of scope)
  captured in [CL-37](clarifications.md). Text-only rendering by
  design; reuses the US-9 `WidgetSnapshot` wire format so no new
  snapshot file, no new App Group key, no new host-side observer,
  no new `WidgetDeepLinkParser` case. Locked by REG-22. Shipped in
  [#26](https://github.com/adamsned/dod-ios-app/pull/26).
- **Widget readability under "Clear" and "Tinted" home-screen
  appearances** — became **US-23** (AC-23.1 through AC-23.6) +
  [CL-39](clarifications.md) + [T-390](tasks.md). Audit-style task
  per the same framing CL-30 established for US-18: inventory every
  home-screen widget surface × every iOS 18+ rendering-mode value
  (`.fullColor` / Standard, `.accented` / Tinted, `.vibrant` /
  Vibrant) plus the existing Standard-dark pair, document the matrix
  in `widget-appearance-audit.md`, and apply targeted fixes for any
  surface that fails. Lock-screen widget (US-22 / T-370, merged via
  PR #26) explicitly scoped out — lock-screen accessory widgets use
  a different system rendering pipeline (monochrome vibrancy on Lock
  Screen, not the home-screen Tinted/Clear pipeline this story
  audits). Clean-audit closure (AC-23.6) explicitly authorized —
  mirror of AC-18.6. Follow-up: T-394 (Featured widget contrast fix
  per [CL-46](clarifications.md) + [AC-23.7](spec.md), parallel
  branch `fix/T-394-widget-text-contrast`) and T-395 (Saved widget
  contrast audit verdict — clean, no source fix needed, per CL-46
  sibling entry, parallel branch
  `fix/T-395-saved-widget-tint-contrast`). Both branches add their
  own copy of CL-46 + AC-23.7 and collide deliberately at merge
  time; T-395's clean-audit verdict means the saved-widget surfaces
  (`WidgetCard.SavedSmall`, `WidgetCard.SavedMedium`,
  `WidgetCard.SavedEmpty`, `WidgetCard.SavedListRow`) ship no source
  change — they enforce AC-23.7 by-construction because the layouts
  render text NEXT TO the `Hero` thumbnail (VStack / HStack), not
  OVER it (no `ZStack` overlay), so the smoking-gun text-over-image
  failure mode T-394 fixes does not exist in `WidgetCard+Saved.swift`
  today.
- **"Saved Recipes" widget description copy rewrite** — became
  **US-25** (AC-25.1 through AC-25.3) + [CL-40](clarifications.md) +
  [T-400](tasks.md). Single user-facing string change in
  `Widget/SavedRecipesWidget.swift`: "Your saved recipes, one tap from
  a cook." → "Quick access to your saved recipes." per CL-40, which
  also captured the three rejected alternatives ("at a glance" /
  "Tap to open…" / "Your bookmarked recipes, right on the home
  screen"). Amends `AC-17.1` (description string superseded with the
  same strike-through treatment T-380 applied to `AC-4.7`).
  Widget-face baselines (`SavedWidgetSnapshotTests`) unaffected — the
  description string lives in the iOS widget gallery UI, not on the
  rendered widget face. Same pattern CL-36 established for the
  "Today's Recipe" → "Latest Recipe" rename.
- **Ratings & Reviews button layout + sticky-actions cleanup** —
  became **US-26** (AC-26.1 through AC-26.5) +
  [CL-41](clarifications.md) (Submit/Cancel order in `CommentComposer`
  with Apple HIG citation) + [CL-42](clarifications.md) (sticky
  `RecipeDetailFloatingActions` removal, explicitly amending T-302's
  Phase 6 polish decision) + [T-410](tasks.md). The nav-bar Save
  (`AC-4.7`, bookmark glyph post-T-380) + Share (`AC-4.8`) are now
  the single in-recipe affordance for both actions; the duplicate
  bottom-trailing sticky stack is removed.
  `RecipeDetailFloatingActions.swift` is deleted; its call site in
  `RecipeDetailView`'s `.overlay(alignment: .bottomTrailing)` is
  removed. `CommentComposer.actions` swaps Cancel + Submit positions
  so Submit (primary) sits at the trailing edge and Cancel
  (`role: .cancel`) at the leading edge — HIG-compliant iPhone sheet
  pattern. AC-4.7 footnote amended to point at CL-42 / US-26;
  US-4 / US-7 / US-13 / US-14 ACs explicitly pinned by AC-26.4.
- **L2 test for new-recipe surfacing** — became regression
  [`REG-16`](spec.md) (no new US — this is a test mandate, not a
  feature) + [`CL-43`](clarifications.md) (why a live newest-post L2
  test in addition to REG-2's fixture-based one) + [`T-420`](tasks.md)
  under the Phase 10 cluster. New L2 test methods live alongside the
  existing `LiveAPITests` suite (constitution §6 L2 tier, gated by
  the same `DOD_RUN_LIVE_TESTS=1` env var, picked up by the existing
  `nightly-live-api.yml` workflow per AC-T3). Two methods:
  `newestPostIsReachableViaFeedRefresh` (asserts the WP REST newest
  post id round-trips through `WPRestClient.posts()` +
  `RecipeStore.cache(listItems:)` + `RecipeStore.listItems(forIDs:)`,
  the production feed-load path), and `newestPostHasNonNilHeroImage`
  (re-asserts REG-2's hero-image invariant against the live newest
  post on every nightly run, not just the fixture's "at least half
  pass" gate).
- **Categories tab brown** — became **US-24** (AC-24.1 through AC-24.6) +
  [CL-44](clarifications.md) + [T-430](tasks.md). Surface-color pass that
  amends T-340's `.insetGrouped` layout on one axis: the scroll surface
  around the inset-grouped row cards AND the area behind the `.searchable`
  field adopt `DODColor.castIronBrown` (the same token the recipe-card
  time chip, offline banner, snackbar, and search filter chip use). The
  surface-vs-cell-level tinting decision is captured in CL-44 — surface
  wins because cell-level can't reach the `.searchable` field's container,
  and repainting cells would blow row-text contrast in both light and
  dark modes (the brand brown does not vary by appearance). Six
  `CategoryListViewSnapshotTests` baselines re-recorded; row text + cells
  + filter logic + view model untouched per AC-24.4.
- **REG-T-360 — Latest Recipe widget hero image** — graduated to
  [CL-45](clarifications.md) + [T-362](tasks.md). T-360 shipped the
  `WidgetImageBridge` (CL-35 Option A) and wired the host-side file
  write inside `RecipeStore.cacheImage(url:bytes:)`, but the only
  production caller of `cacheImage` was `LiveSavedDependencies.preDownloadImages`
  (AC-5.2 saved-recipe pre-download). The feed-load path populated
  the snapshot's `heroImageFilename` strings without ever asking
  `cacheImage` to write the bytes — files never existed, widget fell
  back to placeholder. T-362 adds a fire-and-forget prefetch to
  `LiveFeedDependencies.publishWidgetSnapshot(items:)` that routes
  the trimmed `WidgetSnapshotConfig.maxEntries` hero URLs through
  `ImageLoader.data(for:)` + `RecipeStore.cacheImage(url:bytes:)`,
  letting the existing bridge fire for free. Diagnostic logs
  added inside `cacheImage` and `WidgetImageBridge.writeImage` so
  the next regression of this shape surfaces in `Console.app`.
  Shipped in [#34](https://github.com/adamsned/dod-ios-app/pull/34).
- **App-wide background + foreground color overhaul** — became
  **US-30** (AC-30.1 through AC-30.4) + [CL-51](clarifications.md) +
  [T-520](tasks.md). User-specified hex values per appearance: dark
  mode background `#42210B` and foreground (cards / surfaces / chips)
  `#281F19`; light mode background `#F9F6EF` and foreground `#FFFFFF`.
  Text colors (`DODColor.label`, `DODColor.labelSecondary`) and brand
  accents (`CastIronBrown`, `BurntOrange`, `WarmGold`, `Accent`,
  `Charcoal`, `DarkEarth`) explicitly untouched per AC-30.3 — the
  overhaul is bounded to the two semantic surface tokens. CL-51 maps
  the user-facing "background" / "foreground" intent to the existing
  `DODColor.surface` (screen-wide backdrop) and `DODColor.surfaceElevated`
  (cards / sheets above surface) tokens — the palette has no token
  literally named "background" or "foreground", but Colors.swift's
  doc-comments already pin the semantic role of each. `Cream` and
  `CreamSubtle` are NOT touched even though their names suggest a
  background role — in this codebase `Cream` is the foreground text
  color used on dark brand surfaces (CastIronBrown buttons,
  Snackbar, OfflineBanner, RecipeCard time-chip), not a screen
  background. WCAG AA contrast verified against unchanged text
  tokens: Label on Surface ≥ 10.8:1 and Label on SurfaceElevated ≥
  12:1 in both light and dark; LabelSecondary on the new dark
  surfaces ≥ 5.7:1 (well above the 4.5:1 floor). `accessibility-audit.md`
  contrast table updated with the new hex values. Re-records every
  L4 baseline that includes a surface token — DesignSystem
  components, feature views, widgets, lock-screen text-only baselines
  excluded (no surface visible). Shipped in T-520.

- **REG-T-390 — Home-screen widgets still unreadable in Tinted / Clear**
  — graduated to [CL-48](clarifications.md) + [T-394](tasks.md).
  T-390 / [#27](https://github.com/adamsned/dod-ios-app/pull/27) audited
  the home-screen widgets under iOS 18+ `.accented` rendering and
  concluded 5/6 surfaces passed with a single `widgetAccentedRenderingMode(.fullColor)`
  opt-out on `WidgetCard.Hero`. The user-reported regression — "white
  text on a white background is not acceptable" — was the `WidgetCard.Small`
  recipe title's `.foregroundStyle(.white)` (`WidgetCard.swift:81`)
  collapsing into the wallpaper-tinted default group on light wallpapers
  because the existing three-stop bottom-anchored 110pt gradient
  flattened to the same plane as the title under `.accented` rendering.
  T-394 replaces that three-stop bottom band with a full-height two-stop
  scrim (`.clear` at top → `.black.opacity(0.55)` at bottom) inside the
  `WidgetCard.Small` `ZStack`, giving the `.white` title a calibrated
  WCAG-AA-equivalent contrast scaffold that survives the `.accented`
  flattening pass. The 12 `WidgetCardTintedAppearanceSnapshotTests`
  baselines T-390 added are re-recorded for the populated Small surfaces;
  the Saved + placeholder baselines pass byte-identical because the
  source change is bounded to `WidgetCard.Small`. CL-48 explicitly defers
  AC-23.7 part-(b) (`.widgetAccentable(true)` opt-in on the title) to a
  clean T-39X follow-up if future audit data shows the scrim alone is
  insufficient on extreme-bright wallpapers — the minimal-diff scrim is
  the immediate fix the user-reported regression demands. Shipped in
  [#37](https://github.com/adamsned/dod-ios-app/pull/37).
- **Search-tab polish bundle (5 round-6 items)** — became **US-29**
  (AC-29.1 through AC-29.6) + [CL-49](clarifications.md) +
  [T-500](tasks.md). One PR bundles five small Search-tab polish items
  the user flagged in round 6: (1) "tag search returns 'No recipes
  match'" report, (2) "Clear All" button next to the "Recent" section
  header, (3) `questionmark.folder` → `questionmark.circle` for the
  no-results empty state, (4) removal of the "All categories" menu
  row, (5) "Try" suggestions populate the search field instead of
  selecting a category. CL-49.1 captures the root-cause investigation
  on item 1 — there is no tag-search feature in the code (per CL-3,
  "WP categories only in v1"); the user's misread was a "Try" category
  pill that double-set a filter and dropped every REST result whose
  category map wasn't hydrated yet. Items 1 and 5 resolve to the same
  single action-handler change in `IdleSuggestionsView.onCategoryTap`.
  CL-49.3 explicitly reverses [AC-20.3](spec.md)'s
  `questionmark.folder` carve-out per round-6 user feedback.
  Implementing PR: T-500.
- **Recipe scaling (round-3 backlog, dad's idea)** — graduated to
  **US-31** (AC-31.1 through AC-31.8) + [CL-52](clarifications.md) +
  [T-440](tasks.md). Tap a "Serves N" stepper near the recipe meta row;
  ingredient quantities re-render multiplied by `userServings /
  sourceServings` with cook-friendly fractions (½ × 1.5 → ¾, not 0.75;
  2 ½ × 2 → 5, not 5.0). The new `FractionRenderer` utility lives in
  `DODSupport` so the recipe-detail view + Cook Mode drawer both consume
  the same canonical fraction table (eighth-cup precision per CL-52:
  `{1/8, 1/4, 1/3, 1/2, 2/3, 3/4, 7/8}` + whole numbers, with a 1/16 snap
  tolerance). Source `Recipe.servings` and `RecipeIngredient.text` are
  never mutated — scaling is pure presentation per AC-31.8. Non-blocking
  warning caption renders below the stepper at > 12 servings ("Most home
  dutch ovens (5-quart) cap out around 12 servings. Consider doubling
  the recipe in two batches instead.") with the threshold rationale +
  encapsulation in CL-52. No new analytics, no new persistence schema,
  no new wire format, no `Recipe` / `RecipeIngredient` schema change.
  Stepper range 1...24 (clamped at view-model layer). Cook Mode's
  `CookModeView.init` gains an additive `ingredientScaleFactor: Double = 1.0`
  parameter, defaulted so existing call sites stay unbroken. Locked
  by 26 L1 `FractionRendererTests` cases in `DODSupport` covering the
  four backlog-quote load-bearing examples + the decimal-source snap +
  the canonical fraction table + the warning-threshold boundary, 8 L1
  view-model tests in `RecipeDetailViewModelTests` covering default-fallback /
  source-yield sync / no-op-after-manual / range clamping / scale-factor
  math / warning kick-in / AC-31.7 check-state survival / AC-31.8
  source-recipe immutability, and 6 L4 `RecipeServingsScalerSnapshotTests`
  baselines covering the three scale points (default = 4, scaled-up = 8,
  warning = 16) in light + dark per the constitution §6 L4 mandate.
- **New-recipe surfacing — new Dutch Oven Daddy recipes don't show up in
  the app** — graduated to [REG-18](spec.md) + [CL-50](clarifications.md) +
  [T-510](tasks.md). Root cause traced: `WPRestClient.get(path:queryItems:)`
  built its `URLRequest` with the default `cachePolicy = .useProtocolCachePolicy`
  and no explicit `Cache-Control` request header. WP REST responses carry
  `Last-Modified` but no `Cache-Control`, so iOS `URLSession.shared` applied
  HTTP heuristic freshness (~`0.1 * (now - Last-Modified)`) and served a stale
  page-1 batch from `URLCache.shared` on repeated pull-to-refresh. Cloudflare's
  edge CDN added a second stale layer with a multi-minute TTL on `cf-cache-status: HIT`
  responses — even when URLCache missed, the CDN could return pre-publish JSON
  that omitted a just-published recipe. T-420's REG-16 nightly L2 test didn't
  catch this because it runs in a fresh `swift test` process with an empty
  URLCache and makes one fresh call against a CDN that may happen to be fresh
  at test time; the failure only surfaced under the production user-driven
  repeated-refresh pattern. Fix: two-line addition to `WPRestClient.get(path:queryItems:)`
  that sets `request.cachePolicy = .reloadIgnoringLocalCacheData` (bypasses
  URLCache.shared) AND `request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")`
  (asks Cloudflare to revalidate with origin per RFC 7234 §5.2.1.4). Both
  lines are required: cachePolicy alone leaves the CDN serving stale; the
  header alone leaves URLCache serving stale. CL-50 captures the rejected
  alternatives (per-call `forceFresh: Bool` parameter, cache-busting query
  param, `.reloadIgnoringLocalAndRemoteCacheData`, `.reloadRevalidatingCacheData`,
  global `URLCache.shared` disable). Locked by new L2 test
  `LiveAPITests.feedRefreshBypassesStaleURLCacheEntry` that plants a known-stale
  `CachedURLResponse` in `URLCache.shared` and asserts `WPRestClient.posts()`
  returns the live posts rather than the planted decoy — fails on `origin/main`,
  passes after the fix.
- **"Any time" filter actually composes with the category filter** —
  graduated to [REG-17](spec.md) + [CL-53](clarifications.md) +
  [T-530](tasks.md). Root cause traced: WP REST `/wp/v2/posts?search=...`
  returns `Post.categories: [Int]` on every search hit, but
  `WPDTO.Post.toRecipeListItem(heroImage:)` dropped the categories at the
  network → domain boundary, and `RecipeStore.cache(listItem:)` never
  wrote `categoryIDs` to the cache row. So `RecipeStore.categoryIDs(forRecipeIDs:)`
  returned `[recipeID: []]` for every fresh REST hit whose detail page hadn't
  been opened, and `SearchFilters.apply(...)` line 56's `[]?.contains(10)`
  check resolved to `false` — dropping every fresh REST hit before the
  cook-time chip's predicate ever ran. Layering the Any-time chip on top
  of an already-empty set yielded zero, so the user read this as "the
  Any-time filter doesn't compose with the category filter." CL-49.1's
  prior fix (T-500) had addressed the *idle-state "Try" pill* path by
  routing pills into the query field rather than `filters.categoryID`,
  but the user-driven chip toggle path stayed broken until T-530.
  Fix: propagate the WP categories taxonomy already-on-the-wire through
  the wire → domain → cache pipeline. Three small source edits — one
  Optional `categoryIDs: [Int]?` field on `DODDomain.RecipeListItem`
  (backward-compat with existing Codable payloads via the same Optional-
  with-default-nil pattern `canonicalURL` / `heroImage` /
  `totalTimeDisplay` use), one-line addition to
  `WPDTO.Post.toRecipeListItem(heroImage:)` populating it from
  `WPDTO.Post.categories`, and a guarded write inside
  `RecipeStore.cache(listItem:)` that propagates the value into
  `CachedRecipe.categoryIDs` (mirrors the `canonicalURL` "don't clobber
  a populated value with a nil/empty one" guard at lines 32-34). After
  the fix, picking a category narrows the result set to category-tagged
  REST hits using wire data already in flight, then picking "≤1 hour"
  narrows further to those whose `totalSeconds` is populated AND
  ≤3600 — AND composition end-to-end, no extra network round-trip,
  no schema change. The MISS-on-unknown-totalSeconds semantic for
  recipes the user has never opened is preserved (documented behavior
  per `RecipeStore+IngredientIndex.swift:84-87` and the existing
  `SearchFiltersTests.categoryFilterTreatsUnknownAsMiss` test). CL-53
  captures the rejected alternatives (pre-hydrate `categoryIDsByRecipe`
  on chip toggle via a new REST round-trip; opt-in via a new
  `RecipeStore.injectCategoryIDs(_:)` method threaded from the view-model;
  non-optional `categoryIDs: [Int]` with default `[]` on `RecipeListItem`;
  weakening `SearchFilters.apply(...)`'s missing-vs-empty handling to
  admit unknowns). Locked by new merger test
  `SearchResultMergerTests.composeCategoryAndCookTimeFiltersForFreshRESTResults`
  (the AND composition contract — given a recipe in category C and total-time T,
  `{category: C, maxDuration: T}` includes it; `{category: C, maxDuration: T-1}`
  does NOT), plus companion store-side and network-side tests for the
  round-trip through `cache(listItem:)` and the REST DTO mapping.
  Implementing PR: T-530.
- **Search-tab tweaks — orange Clear All + per-term recent removal (round-7
  "Color refinements" + "Long-press context menus" bundle)** — graduated to
  **US-33** (AC-33.1 through AC-33.4) + [CL-57](clarifications.md) +
  [T-580](tasks.md). Two small round-7 Search-tab affordance polish items
  bundled into one PR because both touch `RecentSearchesView` inside
  `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift`:
  (1) the "Clear All" button's `.foregroundStyle` swaps from
  `DODColor.castIronBrown` (the recipe-card time-chip + offline-banner brown)
  to `DODColor.accent` (the brand orange `#C56A24`, identical to `BurntOrange`)
  so it matches the Recipes-tab gear icon — the gear icon has no explicit
  `.foregroundStyle` / `.tint` modifier in `FeedView.swift:58`, so it inherits
  the app-level `.tint(DODColor.accent)` from `RootView.swift:127` /
  `RootView.swift:161`; (2) each recent-search pill gains a `.contextMenu`
  modifier with one `Button(role: .destructive)` showing
  `Image(systemName: "trash")` + `Text("Clear")`. The button action calls a
  new `SearchViewModel.removeRecentSearch(_:)` method that delegates to a new
  `RecentSearches.remove(_:)` method on the UserDefaults-backed store
  (case-insensitive match, mirrors the `record(_:)` dedupe rule, no-op on
  missing term). CL-57 captures the brand-color match rationale + the
  per-term context-menu pattern + the considered alternatives (warmGold /
  burntOrange tokens, swipe-actions, list restructuring, confirmation
  dialog). The bulk wipe-all path from US-29 / T-500 is unchanged —
  `clearRecentSearches()` stays in place and the Clear All button still
  calls it. One new L1 unit test in `RecentSearchesTests` locks the
  remove-only-target-term contract. Implementing PR: T-580. **Coordination
  note:** T-590 (card long-press → Save) and T-610 (list-cell + search-bar
  color refinement) run on parallel branches against different files —
  spec-file collisions at merge time are expected and the rebaser picks
  the next free CL slot.
- **Gallery ↔ List view toggle on Recipes & Articles + Search (round-7
  "Layout toggle")** — graduated to **US-38** (AC-38.1 through AC-38.6) +
  [CL-64](clarifications.md) + [T-650](tasks.md). New nav-bar button next
  to the Recipes-tab gear icon (and a matching button on the Search tab)
  flips a shared `@AppStorage("dod.recipeListLayout")`-backed layout
  preference between `.gallery` (2-col `LazyVGrid` per CC-9, current
  default) and `.list` (denser `List` with a smaller hero thumbnail +
  title + 1-line excerpt + total-time chip). CL-64 captures the icon
  convention — per Spencer's explicit ask, the button shows the CURRENT
  layout (`square.grid.2x2` in gallery, `list.bullet` in list), opposite
  of the typical iOS pattern (where the icon shows the destination).
  The new `RecipeCard.ListRow` variant lives in `DODDesignSystem`
  alongside the existing `RecipeCard`; a new `RecipeListLayout` enum in
  `DODDesignSystem` carries the two cases + the `@AppStorage` key + the
  toggle's per-case SF Symbol + accessibility label so feature views
  can render the same button without duplicating the convention. The
  same persisted state drives both `FeedView` and `SearchView`, so
  flipping the layout in one tab flips it in the other. US-1 / US-3 /
  US-12 / CC-9's 2-column grid contract is preserved in the
  `.gallery` case (still the default). Implementing PR: T-650.
- **Tab-bar label truncation after T-640 rename (round-8
  regression)** — graduated to amended **AC-37.1** +
  [CL-65](clarifications.md) + [T-660](tasks.md). T-640 renamed the
  Recipes tab to "Recipes & Articles" in both the bottom-tab label
  and the screen header (both sourced from `AppTab.feed.title`); the
  rename worked for the screen header but the system tab-bar item's
  fixed ~80pt width truncated "Recipes & Articles" to "Recipes &
  Arti..." on standard iPhone widths. T-660 introduces a new
  `AppTab.tabLabel: String` computed property — short "Recipes" for
  `.feed`, fallthrough `tabLabel == title` for every other tab — and
  routes the bottom-tab `Label(...)` inside `RootView.phoneTabs`'s
  `TabView` block to read `tabLabel`. `FeedView.navigationTitle`
  continues to read the full "Recipes & Articles" so the screen
  header preserves the full content semantics introduced by T-640.
  CL-65 captures the alternatives (abbreviate the full string,
  `.minimumScaleFactor`, drop the label, alt short words, apply to
  iPad sidebar) and the why-new-property-and-not-shorter-title
  argument. Implementing PR: T-660.

- **Shopping list from saved recipes (round-3 backlog, dad's idea)** —
  graduated to **US-39** (AC-39.1 through AC-39.12) +
  [CL-67 through CL-78](clarifications.md) + the
  [T-680..T-689 cluster](tasks.md). The original round-3 capture sized
  the feature as `M (~1.5 weeks)` and called the aisle classifier "the
  one open design question." The spec amendment resolves twelve
  design questions, not just the one: aisle classifier strategy
  (static keyword map for v1, escalation path to a tagged dictionary
  documented — CL-67); list lifecycle (single global list for v1,
  multi-list deferred — CL-69); quantity merging (per-recipe rows for
  v1, normalized-unit summation deferred — CL-70); cross-recipe
  deduplication (3 rows per recipe instead of 1 merged row — CL-77);
  per-row "I have this" toggle scope (session per-row, no pantry
  inventory — CL-71); iMessage share format
  (`UIActivityViewController` plain-text, no `MessageUI` dependency —
  CL-72); entry surfaces (Saved-tab toolbar + per-card long-press +
  RecipeDetail nav-bar action — CL-73); persistence shape (new
  `ShoppingListItem` `@Model` in SchemaV4 — CL-74); analytics (two
  aisle-only events, constitution §9 amendment — CL-75); empty-state
  copy (`"Your shopping list is empty"` / `"Tap a saved recipe and add
  its ingredients here"` / `cart` — CL-76); location-based
  notifications **DEFERRED** as a Tier-2 future task with a
  `CLLocationManager` + App Privacy bump scope discussion — CL-68;
  iPad layout (same `NavigationSplitView` pattern as Saved per CC-8 —
  CL-78). Implementing PRs: T-680 (this spec PR) + T-681 (domain +
  aisle classifier + L1 tests) + T-682 (SchemaV4 + `ShoppingListItem`
  + migration test) + T-683 (DesignSystem `ShoppingListRow` +
  `AisleSectionHeader` + L4 baselines) + T-684 (new
  `DODFeatureShoppingList` package with `ShoppingListView` +
  `ShoppingListViewModel`) + T-685 (Saved-tab + RecipeDetail entry
  surfaces) + T-686 (share path) + T-687 (analytics + §9 amendment) +
  T-688 (L3 smoke) + T-689 (L5 E2E journey, gated by `e2e` label per
  CL-58). Coordination with the rest of the round-8 parallels: T-660
  already merged; T-670 (phantom searches, Spencer) and T-690 (Voice
  Mode, round-3 dad) are running on their own branches against
  different package families, no source-side collisions with
  T-680..T-689.

- **Login + account system (round-6 Spencer, OAuth framing reversed to CloudKit private-DB sync per dad's architecture-conversation outcome)** —
  graduated to **US-41** (AC-41.1 through AC-41.13) +
  [CL-86 through CL-99](clarifications.md) + the
  [T-700..T-708 cluster](tasks.md). The original round-6 capture sized
  this as `XL (~3-4 weeks iOS side + WP backend longer)` and required
  four constitution amendments (§1 / §3 / §4 / §9) plus the
  GoogleSignIn SDK; **dad chose CloudKit** after weighing four
  alternatives (CloudKit / WordPress users / Firebase or Supabase /
  local-only + manual iCloud sync — per CL-86's full considered-and-rejected
  trail). The pivot dramatically simplifies the original framing:
  there is **no** Account icon, **no** login sheet, **no** OAuth
  providers; the user's iCloud account *is* the sync identity
  (CL-87 carries the OAuth-reversal trail). The CloudKit container
  identifier `iCloud.com.dutchovendaddy.DODApp` matches the bundle-ID
  prefix convention (CL-93). The four constitutional amendments still
  happen but are smaller: §1 acknowledges a v2 sync model
  subsection; §3 adds Apple-provided `CloudKit.framework` to the
  allow-list (no third-party dep — CL-93); §4 adds a "Synced records"
  data-boundary category alongside the existing "Cached data" + "Guest
  identity"; §9 adds four closed-enum analytics events
  (`syncEnabled` / `syncDisabled` / `syncCompletedSuccessfully` /
  `syncFailed(errorCategory:)`) **without** changing the App Privacy
  questionnaire (CL-94 — CloudKit data is the user's iCloud data,
  not "data we collect" per Apple's own App Privacy guidance for
  private-DB-only usage). CL-5's "iCloud sync deferred to v2" is
  explicitly reversed per CL-86; AC-5.7's "reinstall wipes saves"
  limitation is softened (with sync enabled, reinstalling on the
  same Apple ID restores the user's saves from their iCloud private
  DB after the AC-41.2 opt-in flow re-completes). Compliance
  highlights: **App Store Review Guideline 5.1.1(ii)** (app works
  without login — locked by AC-41.1 + REG-26); **5.1.1(v)**
  (account deletion — the AC-41.5 toggle-off + iCloud sign-out path
  satisfies the rule without an explicit Delete button per CL-92);
  **CloudKit private DB only** (no public DB, no shared DB, no
  Discoverability API in v1.0 — locked by REG-25). The Phase 15
  cluster (T-700..T-708): **T-700** ships the spec amendment (this
  PR — US-41 + CL-86..CL-99 + §1/§3/§4 constitution touches + the
  `Marketing/AppPrivacy.md` delta + the `Marketing/TestFlight.md`
  privacy-policy gate); **T-701** ships entitlements + container
  provisioning (`com.apple.developer.icloud-container-identifiers`
  + `com.apple.developer.icloud-services` keys in
  `App/DODApp.entitlements`; `remote-notification` `UIBackgroundModes`
  in `App/Info.plist` + `project.yml`; the App Store Connect
  provisioning steps); **T-702** ships the SwiftData → CloudKit sync
  adapter (`CloudKitSyncAdapter` in `DODPersistence` using the
  iOS 17+ `ModelConfiguration(_:groupContainer:cloudKitDatabase: .private(...))`
  initializer; the `modifiedAt: Date?` additive optional column on
  `CachedRecipe` for AC-41.8's LWW resolution; the per-write
  `modifiedAt` timestamp setting in every `RecipeStore` mutating
  write path); **T-703** ships the Settings → iCloud Sync toggle
  + status sublabel + the AC-41.5 confirmation alert; **T-704** ships
  the AC-41.2 first-launch opt-in sheet; **T-705** ships the offline
  queue + retry + the AC-41.7 status-surface state machine; **T-706**
  ships the AC-41.8 conflict-resolution `LastWriteWinsMergePolicy`
  per CL-90 (LWW for mutable fields, OR for `isSaved`, max-value
  for `lastViewedAt` / `downloadedAt`); **T-707** ships the four new
  analytics events + the constitution §9 allowlist amendment per
  CL-96; **T-708** ships the L1 + L3 + L5 test coverage including
  the `MockCKContainer` testability seam + the
  `test_appLaunchesUnderNoiCloudAccount` smoke per REG-26 + the
  `test_cloudKitSyncEnableSaveVerifyDisableCleared` L5 E2E journey
  (gated by `e2e` label per CL-58). **Two explicit deferrals:** (i)
  `PersistentShoppingListItem` syncing waits until T-682 ships the
  SwiftData @Model (per CL-88's sub-decision — shopping list remains
  per-device until then); (ii) Google Play / Android non-applicability
  (per CL-98 — no Android target exists; if/when constitution §2 is
  amended to add Android, the natural path is Firebase Auth + Firestore
  per the documented re-evaluation trigger). Implementing PRs: T-700
  (this spec PR) + T-701..T-708. The Phase 15 cluster runs without
  parallel round-9 work in-flight, so T-700 reserves CL-86..CL-99
  (CL-84 skipped per the Phase 13 parallel renumbering), US-41,
  T-700..T-708 cleanly with no rebase collisions.