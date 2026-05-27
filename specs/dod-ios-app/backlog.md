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

- **Add more standard settings.** Round out the Settings page (T-550) with the rest of what users expect from a recipe-app settings surface. Reasonable candidates to evaluate at spec time: notification preferences (when new recipes drop, weekly digest), default Cook Mode behavior (keep-screen-awake toggle vs always-on), default share format (link vs full text), data + cache management ("Clear image cache" / saved-recipes count), accessibility shortcuts (text size override, reduce motion), telemetry opt-out (per constitution §9), legal links (privacy policy, terms). Size: **M** — the audit-and-pick is the hardest part; each individual row is XS.

- **"About Ned Adams & Dutch Oven Daddy" — shorter paragraph + image.** The current placeholder paragraph in T-550's Settings → About row is too long for a phone screen. Replace with this exact copy:

  > Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!

  Also include the photo of Ned (the one Spencer attached in this round-7 capture — kitchen background, holding a black cast-iron dutch oven, blue shirt + brown leather apron). **Image-to-paragraph ratio should be appropriate** — the image is a portrait accent for the text, not a hero. Recommend ~120pt wide on iPhone, leading-aligned with the paragraph wrapping to its right (like a magazine sidebar layout) OR top-anchored above the paragraph if the wrap doesn't read well.

  **Asset prep:** Spencer attached the image to the conversation but Claude Code's attachment store wasn't reachable from Bash, so the binary wasn't saved to the repo automatically. The next agent that builds this should:
  1. Ask Spencer for the image again, OR
  2. Pull it from `https://www.dutchovendaddy.com/about-me/` (the existing About-Me page likely hosts the same photo)
  3. Save under `App/Assets.xcassets/AboutNed.imageset/` (or as a Markdown-rendered asset if About content is HTML-based)

  Size: **S** for the copy + asset wire-up. Supersedes T-552 (About Me fetch) since the copy is now embedded, not fetched — capture that supersession in the CL when this graduates.

#### New recipe-detail action

- **Download for offline viewing button (`square.and.arrow.down`).** Adds a third nav-bar action next to Save (`bookmark`, AC-4.7) and Share (`AC-4.8`). Tap → download the recipe payload (text + ingredients + steps + hero image at full resolution) for on-device offline access. "Perfect for camping when you don't have access to internet." Semantically distinct from Save (which is "I want to remember this") — Download is "I want to use this without network." A saved recipe is auto-downloaded per AC-5.2; download alone is a save without the bookmarking. Spec question: do Download and Save share storage? Are they separate concepts in the UI? Probably yes-and-yes with a UX distinction. Size: **M** — backend reuse is straightforward, the UX question is what makes it medium.

#### Recipes tab rename + content typing

_(Graduated 2026-05-27 as US-37 / CL-63 / T-640. Spec amends CL-9 + CL-10 + AC-1.7 + AC-4.11 — original wording struck through; lineage captured in CL-63.)_

#### Layout toggle

- **Gallery ↔ List view toggle.** New button on the Recipes & Articles tab (and Search tab) that swaps between two layouts:
  - **Gallery view** (current default): the 2-col grid per CC-9.
  - **List view** (new): smaller images, smaller card text, denser rows for quick scanning.

  Icon toggle:
  - When in gallery view → button shows `square.grid.2x2` (the icon represents "switch TO list mode" implicitly; *or* read as "currently showing grid" — clarify with user at spec time)
  - When in list view → button shows `list.bullet`

  Wait — Spencer's wording is: *"if user is in gallery view, the button displays the icon `square.grid.2x2`"* — so the icon represents the CURRENT mode, not the destination. This is the opposite of typical iOS convention (where the toggle shows what you'll switch TO). Either is defensible; capture choice in CL. Whichever wins, both surfaces (Recipes tab + Search tab) need to honor the same convention.

  Size: **M**. Persistence question: does view choice persist across launches? Probably yes — UserDefaults flag.

#### Long-press context menus

- ~~**Recipe/Article card long-press → "Save" with `bookmark.fill` icon.** Standard SwiftUI `.contextMenu` on the card. Tap menu item → save the recipe/article to the Saved tab (same code path as AC-5.1 tap-the-bookmark-on-detail flow). Works in both gallery and list view. Size: **S**.~~ **Graduated 2026-05-27 as US-34 / CL-60 / T-590.**

- ~~**Recent search long-press → "Clear" with `trash` icon, deletes only that term.**~~ Graduated → US-33 / CL-57 / T-580 as part of the Search-tab tweaks bundle.

#### Color refinements

- ~~**"Clear All" button in Search tab should match the gear-icon orange in Recipes tab.**~~ Graduated → US-33 / CL-57 / T-580 as part of the Search-tab tweaks bundle. Token: `DODColor.accent` (the gear icon inherits the app-level `.tint(DODColor.accent)` from `RootView.swift`).

- ~~**List cells + search bars: `#553724` in dark mode, `#FFFFFF` in light mode.**~~ — Graduated to CL-59 / T-610 as a further refinement of `SurfaceElevated` dark from `#5A3520` to `#553724` (Option A — single hex tweak; light stays `#FFFFFF`). Snapshot re-record remains T-571's deferred scope.

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| Standard settings expansion | M | Audit-and-pick |
| About Ned copy + photo | S | Asset prep open question |
| Download button | M | Reuse cache, define UX distinction from Save |
| Recipes & Articles rename + article-rendering path | M | Amends CL-9 / AC-1.7 / AC-4.11 |
| Gallery ↔ List view toggle | M | Plus icon-direction CL |
| Card long-press → Save | S | SwiftUI `.contextMenu` |
| ~~Recent long-press → Clear~~ | ~~S~~ | Graduated → US-33 / CL-57 / T-580 |
| ~~Clear All orange color match~~ | ~~XS~~ | Graduated → US-33 / CL-57 / T-580 |
| ~~List-cell + search-bar color refinement~~ | ~~S–M~~ | Graduated → CL-59 / T-610 (Option A: refine `SurfaceElevated` dark `#5A3520` → `#553724`) |

**Next session also picks up these existing items per Spencer's batching note:**
- Round-3 dad: **Shopping List** (~1.5 weeks)
- Round-3 dad: **Voice Mode** (~2 weeks)

**Still paused (Spencer + dad architecture conversation in progress):**
- Round-6 spencer: **Login + OAuth** (XL — requires constitution amendments §1/§3/§4/§9)

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

- **Login + account system (Google + Apple + email).** Account icon in the Recipes tab's top-right nav corner; tap → login sheet with three options. Name + email persist across the app for save / comment / rate flows.

  **Constitutional conflicts to surface BEFORE any code:**
  1. **§1 Product identity:** today says "mostly read-only with two write surfaces." Login changes the app's identity considerably — it stops being anonymous.
  2. **§4 Content source:** "No auth required for reads in v1. Anonymous client." Would need to amend.
  3. **§9 Privacy & security:** today uses Keychain-stored guest identity (CL-21/22 — name+email for comments/ratings) sent only to dutchovendaddy.com. OAuth adds Google + Apple as third parties; the App Privacy questionnaire changes meaningfully (now collecting account credentials). The "no IDFA, no cross-app tracking" stance survives Sign in with Apple but breaks under Google Sign-In without careful scope handling.
  4. **§3 Dependencies:** would need `GoogleSignIn` SDK; `Sign in with Apple` uses system `AuthenticationServices` (no new dep). Both need plan-time approval.
  5. **CL-5 (iCloud sync deferred to v2):** today says saved recipes are device-local. A real account opens server-side sync of saves + comments + ratings; the spec needs to decide whether login implies sync or whether they're still independent.

  **Backend implications:** dutchovendaddy.com's WordPress doesn't natively support OAuth account creation — adding it requires a WP plugin (e.g., MiniOrange, WPOAuth) or a side service. This is a paired web + iOS effort, not iOS-only.

  Size: **XL** (~3–4 weeks for the iOS side alone; backend longer). **Paused pending architecture conversation with dad before graduating.**

#### Sizing summary

| Item | Size | Notes |
|---|---|---|
| ~~1. Tag search "No recipes match"~~ | ~~S~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~2. "Clear All" recents button~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~3. `questionmark.circle` not `.folder`~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~4. Remove "All categories" button~~ | ~~XS~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~5. "Try" suggestions fill search bar~~ | ~~S~~ | Graduated to US-29 / CL-49 / T-500 |
| ~~6. "Any time" filter composes~~ | ~~M~~ | Graduated → REG-17 / CL-53 / T-530 |
| 7. Login + OAuth | XL | **Constitution amendment first** |
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
