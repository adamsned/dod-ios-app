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

_All four 2026-05-24 captures have graduated to spec-driven work and
shipped. See "Recently graduated" below for the trail._

### Captured 2026-05-24 (post-Phase-8 round 2, @spencer0706)

- **Categories tab — modernize visual language.** The Categories tab
  feels stale next to the rest of the app. Restyle to match current
  iOS design conventions (cell styling, header treatment, spacing).
  Size: M. Open question for spec time: is this a token-level change
  in `DODDesignSystem` (which would affect other surfaces) or a
  Categories-only layout pass? Worth a design pass before specifying.

- **Search tab — `tag.fill` instead of folder icon on tags.** The
  current folder SF Symbol on the tag chips reads as "navigate into a
  folder" rather than "filter by tag" — pure SF Symbol swap to
  `tag.fill` should fix the affordance. Size: S. Verify the chip
  visuals still balance with the symbol's bounding box; if not, may
  need spacing tweaks too.

- **Widget readability under "Clear" and "Tinted" home-screen
  appearances.** iOS 18+ home-screen icon/widget modes (Clear, Tinted,
  Dark beyond standard dark mode) wash out the existing widget cards.
  Need to audit `WidgetCard` (both featured and saved variants) in all
  three appearances and ensure text + key visual elements stay
  legible. Likely needs `widgetAccentedRenderingMode` / accent-color
  handling. Size: M. Pair with US-18 audit-style framing — produce a
  matrix and fix what fails.

- **"Today's Recipe" widget → rename + show real recipe image.** Two
  changes to the existing US-9 widget:
  1. Rename display name from "Today's Recipe" to "Latest Recipe"
     (less ambiguous about cadence — the widget already reflects the
     most recent post, not a daily-curated pick).
  2. The placeholder knife-and-fork glyph should be replaced with the
     actual recipe hero image. The widget already has the recipe ID;
     needs the host to ensure the hero image is exported to the App
     Group container so the widget extension can render it (saved
     widget hit the same limitation per T-322's nil-filename note).
  Size: M for the image bridge, S for the rename. Will need a CL on
  the rename in case anyone has the old name pinned in screenshots
  or marketing.

- **Lock-screen widget for "Latest Recipe" (rectangular).** Add a
  rectangular-family lock-screen widget that shows the latest
  recipe's title + short description as text only. Lock-screen
  widgets are text/info-only by design (no image rendering, monochrome
  rendering pipeline) so this is a clean addition — reuses the same
  snapshot the home-screen widget reads, just in a different
  `WidgetConfiguration` with a `.accessoryRectangular` family.
  Size: M. AC will need to cover the iOS 16+ availability gate (same
  pattern as US-11's `ActivityKit` gate).

- **Heart → bookmark everywhere in the saved-recipes context.**
  Reverses the in-recipe carve-out from AC-16.3 (which left the
  navigation-bar Save heart on `RecipeDetailView` intentionally
  unchanged). The user is now saying the icons should be consistent
  with the Saved tab — bookmark everywhere. Touches:
  1. `RecipeDetailView` navigation-bar Save button (AC-4.7 / AC-5.1 —
     "Save button (heart icon)") — change wording in spec, swap glyph.
  2. AC-5.8 empty-state copy "Tap the heart on any recipe to save it
     for offline" — reword to "Tap the bookmark…".
  3. Audit anywhere else "heart" appears in copy or imagery in
     saved-context (search results, related-recipes, etc.).
  This is a deliberate amendment to AC-16.3 — when this graduates,
  the clarification should explicitly note that CL-24 (which fixed
  the tab icon) is now extended to the in-recipe surface too. Size: S
  for the swap; the audit-for-stray-hearts is what makes it M.

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
