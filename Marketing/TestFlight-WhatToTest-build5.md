# TestFlight "What to Test" — Dutch Oven Daddy 1.0 (5)

Paste the block below into App Store Connect → TestFlight → (this build) →
Test Details / "What to Test" before notifying internal testers.

> Before submitting this build: deploy the CloudKit schema to Production
> (round-12 backlog bug — "CloudKit recipe sync doesn't work"). TestFlight
> builds use the CloudKit Production environment, which never auto-creates
> record types — until the schema is deployed there, iCloud Sync will keep
> failing on-device no matter what the app does. Run a Debug build with sync
> ON and save a recipe (creates the types in Development), then CloudKit
> Console → Deploy Schema Changes → Production.

---

What's new in build 5

Articles look right now. Round-up posts like The Best Dutch Oven Recipes used
to render as a wall of run-together text. They now show proper headings,
paragraphs, photos, and numbered/bulleted lists.
- To test: open an article post (e.g. a "best of" round-up) and confirm it
  reads cleanly — headings stand out, images are sized sensibly, lists are
  formatted.

Tap a recipe link inside an article and it opens in the app. In a round-up
article, tapping one of the linked recipes now jumps straight to that recipe
inside DOD instead of kicking you out to Safari.
- To test: open the Best Dutch Oven Recipes round-up, tap a recipe link in the
  body, and it should open that recipe in the app. Links to non-recipe pages
  (e.g. "About") or other websites should still open in the browser.

Smarter search. When a search turns up few results, you get a "Did you mean...?"
suggestion, and category names now match too.
- To test: search a slightly-misspelled or unusual term and look for the
  suggestion; try a category word (e.g. "breakfast").

iCloud Sync — please re-test. We're still chasing why saved recipes weren't
syncing across devices. Two changes this build:
- The Settings → iCloud Sync toggle now shows "Relaunch DOD to apply" after you
  flip it — the setting only takes effect on a fresh launch, so flipping it and
  waiting will look like nothing happened. Quit and reopen the app to actually
  turn sync on/off.
- Behind the scenes, the app now logs detailed sync activity (helps us pinpoint
  the issue).
- To test (after the schema deploy above): turn iCloud Sync on, relaunch, save
  a few recipes, then open DOD on a second device signed into the same iCloud
  account and check whether they appear in Saved. If they still don't sync,
  that's the very thing we're diagnosing — just note it.

Polish. Text now uses the system font throughout for a more native feel; small
layout and cook-time-filter refinements.

While you're in there, two quick re-checks (these were fixed in code but need a
real-device confirm):
- Widgets: add the Latest Recipe and Saved widgets to your home screen and
  confirm they show a real recipe image (not the fork-and-knife placeholder),
  and that text is readable in Tinted mode.
- Comments: open a recipe, post a test comment, confirm it appears.

Please also sanity-check the everyday flows: browsing the Recipes feed, search,
saving/unsaving, recipe detail, Cook Mode with timers and voice, and that the
app still opens reliably after a force-quit (build 4's relaunch-crash fix is
included).

Heads-up: cross-device iCloud Sync needs both devices on the same iCloud
account, sync turned on and the app relaunched on each, and a moment to
propagate — give it a minute before deciding it didn't work.
