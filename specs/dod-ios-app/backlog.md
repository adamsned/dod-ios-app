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

### Captured 2026-05-24 (post-Phase-8 round 2, @spencer0706)

_(empty — all items graduated; see "Recently graduated" below.)_

### Captured 2026-05-25 (round 3, @adamsned)

User has chosen to defer TestFlight until at least round 3 ships. These
three items each turn a feature the website *can't* easily replicate
into a reason the native app exists. Tier 1 from the consultant pass on
2026-05-25.

- **Cooking Voice Mode** — hands-free recipe reading during Cook Mode.
  "Hey Siri, next step / repeat / pause / what was that?" Uses on-device
  `AVSpeechSynthesizer` so no network round-trip, no subscription cost,
  no privacy surface. Pairs with the existing Cook Mode + Live Activity
  infrastructure: the current step the Live Activity highlights is the
  same step Voice Mode reads aloud. Probably wants a `CL-` entry on
  whether to also wire up an App Intent (`ReadNextStepIntent`) so Siri
  can drive it without the app being foregrounded. Size: **M**
  (~2 weeks). The biggest differentiator we could ship vs. every other
  food-blog reader on the App Store.

- **Shopping list from saved recipes** — select N saved recipes →
  "Add to shopping list" → ingredients grouped by aisle (produce /
  pantry / dairy / meat / spices / other) with checkable items and an
  "I already have this" toggle per ingredient. Share-via-iMessage as the
  primary export (perfect for sending the list to a spouse on the way to
  the store). Pure local SwiftData; no WP backend involvement. The
  aisle classifier is the one open design question — could be a small
  static keyword map (good enough for v1), could escalate to a
  category-tagged ingredient dictionary later. Size: **M** (~1.5 weeks).
  Turns the recipe app you cook *from* into the grocery list you shop
  *from*. Massive utility loop.

- **Recipe scaling** — tap "Serves 4" → stepper or slider → choose new
  serving count → all ingredient quantities multiply with proper
  fraction handling (½ cup × 1.5 → ¾ cup, not 0.75). Optional warning
  at scales the typical home dutch oven physically can't hold (rough
  rule: >12 servings on a 5-quart). Pure presentation logic; no schema
  change since the source recipe is untouched. Size: **S** (~3 days).
  Every recipe-app review on the App Store wants this and almost
  nobody does it well.

**Explicitly deferred from this round** (consultant Tier 2+ — capture
later if v1.x user reviews call for them): Universal Links to the
website, Recipe Collections ("Cookbooks"), Apple Watch + complications,
background app refresh, daily push notification, photo-with-comment.
Don't graduate these into spec work without a real user signal — they
either need a paired web-side effort (Universal Links) or have
non-trivial scope risk (Watch, Collections).

### Captured 2026-05-25 (round 4, @spencer0706)

Mix of new surfaces, polish, an L2 test addition, and two regression
reports against work that just shipped (items marked **REG-** in the
notes). Captured after using the post-round-2 build on iPhone 16 sim.

#### New surfaces / features

- **Settings page** — new top-level surface reached from a **gear icon**
  in the top corner of the Recipes (Feed) tab. Layout styled to match
  the Categories tab (`.insetGrouped` list per T-340 / CL-32). Initial
  content (each its own row group):
  1. **Imperial ↔ metric measurement toggle.** Affects every ingredient
     quantity rendered in recipe detail + Cook Mode. Pure presentation
     transform — source JSON-LD stays untouched. Open question for
     spec time: what's the default for a fresh install (US-locale → imperial,
     metric for everywhere else)? Persist to UserDefaults.
  2. **About Me section.** Pull the "About Me" content from
     [`https://www.dutchovendaddy.com/about-me/`](https://www.dutchovendaddy.com/about-me/).
     Open question for spec time: fetch live each visit, fetch once
     and cache offline (preferred), or copy-paste the text at build
     time? Live fetch with cache + offline fallback is the most natural
     fit with the existing CL-1 hybrid strategy. WP REST exposes
     `/wp/v2/pages?slug=about-me` for this.
  3. **Version + build number footer.** Display
     `CFBundleShortVersionString (CFBundleVersion)` (e.g. "1.0.2 (47)")
     as a centered footnote-style label at the bottom of the screen.
     Reads from `Bundle.main.infoDictionary`. Trivial — bundled here
     because it's the natural place to land. Size: **XS** on its own.

  Total size: **L** (~1 week). Split into multiple T-NNN tasks at spec
  time — the imperial/metric transform is its own work item separate
  from the About Me fetch and from the gear-icon entry-point plumbing.

#### Polish

- **Ratings & Reviews button layout + sticky-actions cleanup.**
  - **Swap "Submit" and "Cancel" button positions** in the rating-submit
    composer. Worth a CL on the iOS convention here — typically primary
    actions live at the trailing/right edge with cancel at leading/left
    on iPhone, but `confirmationDialog` and `alert` defaults differ.
    Capture the chosen pattern + cite Apple HIG when this graduates.
  - **Remove the sticky save + share buttons above the tab bar** on
    `RecipeDetailView`. T-302 added these as a floating-actions row
    (`RecipeDetailFloatingActions.swift`) so the affordances stay
    reachable when scrolled past the hero. User is now saying the
    top-of-screen save + share (in the navigation bar, `AC-4.7` +
    `AC-4.8`) are sufficient and the sticky duplicates clutter the
    bottom. Removes one file (`RecipeDetailFloatingActions.swift`) plus
    its call site in `RecipeDetailView`. Amends the post-Phase-6 T-302
    "polish" decision. Size: **S** (~1h).

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

- **"Saved Recipes" widget description copy.** Current
  `.configurationDescription(_:)` string on `SavedRecipesWidget` reads
  awkwardly — needs a rewrite to something more natural. Pure string
  change in `Widget/SavedRecipesWidget.swift`. Worth a CL noting the
  rewrite (user-facing widget gallery copy), same pattern CL-36 used
  for the "Today's Recipe" → "Latest Recipe" rename. Size: **XS**
  (~30min including the CL).

#### Tests

- **L2 test for new-recipe surfacing.** When a recipe is published on
  dutchovendaddy.com, verify the app's feed (US-1 `/wp/v2/posts` query)
  picks it up. Lives in the existing **L2 nightly live-API tier**
  (constitution §6 / AC-T3). Tags as `live-api`; doesn't gate PRs but
  surfaces contract drift early. Approach: read the WP feed's newest
  post id at test time, assert it's present in the app's `RecipeStore`
  after a `feed.refresh()`. Companion check: post's `_embed`'d
  `wp:featuredmedia` round-trips into a non-nil `heroImage` (already
  pinned by `REG-2` but worth re-asserting against the newest post on
  every nightly run, not just the fixture). Size: **S** (~2h — one new
  test plus the helper that fetches "newest post id"). New regression
  ID: `REG-16`.

#### Regression reports — work that just shipped but the user still sees broken

- **REG-T-360 — "Latest Recipe" widget still shows fork-and-knife.**
  T-360 / [#24](https://github.com/adamsned/dod-ios-app/pull/24) built
  the file-export image bridge (CL-35 Option A) and wired the featured
  widget to render real images via `WidgetImageBridge.fileURL(forFilename:)`.
  User reports the widget still renders the placeholder glyph after
  reinstalling the app, browsing the feed, and waiting for snapshots
  to refresh. Possible causes worth investigating before treating as a
  confirmed bug:
  1. **Fresh-install transient.** `RecipeStore.cacheImage(...)` only
     fires when the app actually loads image bytes; if the feed loaded
     but the hero images haven't been pre-cached yet, the App Group
     directory is empty and the widget falls back to placeholder per
     `CL-35.3`. Wait ~30s after a feed scroll, then check.
  2. **Bridge isn't writing.** The `feat(T-360)` impl plumbed
     filenames into the snapshot writer in `LiveFeedDependencies.publishWidgetSnapshot`,
     but the host-side file write happens in
     `RecipeStore+ImageCache.swift`. Verify the write actually fires
     by inspecting `~/Library/Developer/CoreSimulator/Devices/.../Shared/AppGroup/<group-id>/`
     for `*.img` files.
  3. **Widget timeline cache.** WidgetCenter may still be holding the
     pre-T-360 timeline; force-reload via `WidgetCenter.shared.reloadAllTimelines()`
     during testing.

  If investigation confirms the bridge isn't populating files on the
  host side, this becomes a fix for `T-360`'s implementation. Size:
  **M** (debug + fix). Reference [`CL-35`](clarifications.md),
  [`AC-21.2`](spec.md), [`AC-21.3`](spec.md).

- **REG-T-390 — Home-screen widgets still unreadable in Tinted / Clear.**
  T-390 / [#27](https://github.com/adamsned/dod-ios-app/pull/27) audited
  the widgets under iOS 18+'s accented rendering modes (Tinted +
  Clear both surface as `widgetRenderingMode == .accented`) and
  concluded 5/6 surfaces passed, applying only one surgical fix
  (`widgetAccentedRenderingMode(.fullColor)` on the hero `Image` in
  `WidgetCard.Hero.loadedImage(_:)`). User reports: **"white text on
  a white background is not acceptable"** — the recipe title rendered
  over the hero in `WidgetCard.Small` (`.foregroundStyle(.white)` per
  the codebase audit at `WidgetCard.swift:67–69`) is invisible against
  a light wallpaper in the accented mode because `containerBackground`
  is stripped and the `.white` literal doesn't tint correctly. The
  T-390 audit's "system desaturation handles it" assumption was wrong
  — the codebase-tinting-risk research artifact at
  `/tmp/widget-audit-research/codebase-tinting-risk.md` flagged exactly
  this as the smoking gun and was overridden by the main agent's
  inspection. **What to fix:** replace `.foregroundStyle(.white)` on
  text that renders over the hero with a system semantic color (e.g.
  `.primary` with `widgetAccentable()` opt-in), OR force-add a
  contrast-providing scrim behind the title. Apply the same fix to
  `SavedRecipesWidget` rows. Size: **M** (~3h — investigate every
  hardcoded text color in the widget views, fix, re-record the 12
  Tinted/Vibrant baselines T-390 added). Reference
  [`AC-23`](spec.md), [`CL-39`](clarifications.md). This becomes a
  **T-394** follow-up under T-390's existing follow-up list (T-391..T-393).

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| Settings page | L | Splits into multiple T-NNN at spec time |
| Ratings layout cleanup | S | Amends T-302 |
| Categories tab brown | S–M | Needs CL on cell-vs-surface tinting |
| Saved widget description | XS | Single string + CL |
| L2 new-recipe test | S | New REG-16 |
| REG-T-360 widget image | M | Investigate fresh-install transient first |
| REG-T-390 widget text | M | T-390 was overconfident; T-394 follow-up |

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
  mirror of AC-18.6.
