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
