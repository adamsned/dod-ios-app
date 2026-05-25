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
