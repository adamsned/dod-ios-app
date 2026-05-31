# TestFlight "What to Test" — Dutch Oven Daddy 1.0 (3)

Paste the block below into App Store Connect → TestFlight → (this build) →
**Test Details / "What to Test"** before notifying internal testers.

> ⚠️ Before submitting this build: confirm the **"Optional iCloud Sync"**
> paragraph is live at https://www.dutchovendaddy.com/app-privacy/ (the
> AC-41.12 privacy gate — this is the first build that turns CloudKit sync
> on). Text is in `Marketing/AppPrivacy.md` § "The TestFlight gate".

---

**What's new in build 3**

🆕 **iCloud Sync (optional).** Your saved recipes can now sync across your
Apple devices.
- On first launch you'll see a "Sync your saved recipes across devices"
  prompt — please try it once. (Tapping **Not now** is fine and is also
  worth testing — it should never ask again.)
- You can turn it on/off anytime in **Settings → iCloud Sync**.
- **To test the sync:** save a few recipes, turn iCloud Sync on, then open
  the app on a second Apple device signed into the **same** iCloud account —
  your saved recipes should appear there within a minute or two. Then toggle
  sync **off** and confirm the synced copies clear.
- The app should behave exactly as before if you're not signed into iCloud,
  or if you decline the prompt — nothing should break.

🆕 **Cook Mode voice.** Recipe steps now read aloud in a natural-sounding
voice instead of the old robotic one.
- **Settings → Cook Mode voice** lets you pick **Female / Male / No
  preference**.
- **To test:** open any recipe → **Cook Now** → start Voice Mode and listen
  to a step. Change the gender in Settings, then advance to the next step and
  confirm it reads in the new voice (no need to restart Cook Mode).

**Please also sanity-check the everyday flows still work:** browsing the
Recipes feed, search, saving/unsaving, recipe detail, Cook Mode timers, and
the home-screen + lock-screen widgets.

**Heads-up:** cross-device sync needs both devices on the **same** iCloud
account and a moment to propagate — give it a minute before deciding it
didn't work.
