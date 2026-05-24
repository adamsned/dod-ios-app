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

- **Swap "Search" and "Saved" tab positions.** Within US-1 navigation; no
  spec amendment needed. (~1h)
- **Heart → bookmark on the Saved tab icon.** Pure icon swap. (~30min)
- **Saved-recipes home-screen widget.** A *second* widget distinct from
  the existing today's-featured one. Existing `WidgetSnapshotStore` would
  gain a parallel "savedRecipes" entrypoint; the widget extension would
  gain a second `WidgetConfiguration`. Worth a real US-NN amendment when
  it goes through spec orchestration.
- **Light/dark mode polish.** Full AX5 dynamic-type sweep across every
  screen in both appearances; fix anything that misreads. Worth its own
  task cluster.
