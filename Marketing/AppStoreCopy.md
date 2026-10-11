# App Store Marketing Copy — v1.0

**Status:** rewritten 2026-10-11 against `main` @ `123ebabf`. Every feature named here ships on `main`. Owner-approve before submission.

## App name (max 30 characters)

```
Dutch Oven Daddy
```

## Subtitle (max 30 characters)

```
Cast iron cooking recipes
```

## Promotional Text (max 170 chars — editable post-launch without a new build)

```
Cast iron and Dutch oven recipes from dutchovendaddy.com, with a hands-free Cook Mode, coal counts from Heat Coach, and your saved recipes offline.
```

## Description (max 4000 chars)

```
Dutch Oven Daddy is the official app for dutchovendaddy.com, the cast iron and Dutch oven recipe blog. Every recipe, plus the tools to cook it, on your iPhone and iPad.

FIND SOMETHING TO COOK

• Browse the latest recipes and articles, or explore by category: beef, chicken, sides, desserts, sourdough, and more.
• Search the whole blog.
• Save recipes to read offline. Spotty campsite or kitchen Wi-Fi can't break your cook.
• Not sure what to make? Tap Surprise Me.

COOK IT

• Cook Mode walks you through one step at a time with large type, built-in step timers, and the screen kept awake.
• Have the steps read aloud, and move through them hands-free.
• Timers show on your Lock Screen and in the Dynamic Island.
• Tap ingredients to check them off as you go.
• Switch to metric units in Settings.

COOKING TOOLS

• Heat Coach: pick your Dutch oven size and cooking style, adjust for wind, weather, and elevation, and get a starting coal count for the lid and underneath.
• Your First Cookout: a guided first cook for beginners, from gathering gear to the finished dish.
• Cooking Journal: log what you cooked, with photos.
• Shopping List: keep the ingredients you need in one place.

MADE FOR IPHONE AND IPAD

• Home Screen and Lock Screen widgets for the latest recipe, your saved recipes, and cooking tips.
• Siri and Shortcuts: open a recipe, start Cook Mode, or show your saved recipes.
• Optional iCloud Sync keeps your saved recipes on all your devices.
• A full iPad layout with a sidebar.

JOIN IN

• Rate recipes and leave comments.
• Sign in with Apple or Google if you like. It is optional; the whole app works without an account.

PRIVACY

Your saved recipes, journal, and shopping list stay on your device. The app has no third-party ads. It sends anonymous usage data that you can turn off in Settings. Full details: dutchovendaddy.com/app-privacy/

REQUIREMENTS

iPhone or iPad with iOS 17 or later.
```

## Keywords (max 100 chars total, comma-separated)

```
cast iron,skillet,recipes,sourdough,camping,campfire,baking,bread,cooking,timer,grill,bbq,camp
```

## What's New (release notes) for v1.0

```
Welcome to the Dutch Oven Daddy app! Browse, search, and save cast iron and Dutch oven recipes from dutchovendaddy.com, then cook them step by step with Cook Mode.
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://dutchovendaddy.com/contact/` |
| Marketing URL | `https://www.dutchovendaddy.com/` |
| Privacy Policy URL | `https://www.dutchovendaddy.com/app-privacy/` |

The Support URL is the existing contact page (the same one the Settings → Contact Support row opens). The Privacy Policy URL must match the in-app link (`SettingsViewModel.privacyPolicyURLString`); its published text is kept in `Marketing/PrivacyPolicy.md`.

## Categories

Primary: **Food & Drink**. Secondary: **Lifestyle**.

## Age rating questionnaire

App Store Connect computes the rating from these answers; do not assume 4+.

| Question | Answer | Why |
|---|---|---|
| User-generated content | **Yes** | Recipe comments and ratings. Moderated on dutchovendaddy.com; in-app Report Comment and Block. |
| Messaging / chat between users | No | Comments are public posts, not messages. |
| Advertising | No | No third-party ads. |
| Unrestricted web access | No | External links open in the system browser. |
| Gambling, contests | No | |
| Violence, sexual content, profanity, horror, medical | None | |
| Alcohol, tobacco, or drug use or references | **Owner call** | Some recipes use beer, wine, or bourbon as an ingredient. "None" is defensible (no depiction of use); "Infrequent/Mild" is the cautious answer and raises the rating. |

## Notes for App Review

Paste into App Store Connect → App Review Information → Notes.

```
No account is needed to review the app. Every feature works as a guest; Sign in with Apple and Sign in with Google are optional, offered from the profile screen.

Account deletion (5.1.1(v)): open the profile and tap Delete Profile. This erases the profile and sign-in details from the device and revokes the Sign in with Apple token through a first-party, stateless Cloudflare Worker that calls Apple's /auth/revoke. Google sign-in is disconnected the same way.

User-generated content (1.2): recipe comments are posted to and moderated on dutchovendaddy.com. In the app, tap a commenter or long-press a comment to Report Comment or Block the author. Contact: daddy@dutchovendaddy.com, also reachable from Settings → Contact Support.

Privacy (5.1.1): Settings → Data & Privacy has the Privacy Policy link, a Privacy Dashboard showing where each kind of data lives, Export My Data, and the switch that turns off anonymous usage data.

iCloud: optional. Saved recipes sync through the user's private CloudKit database only (no public or shared database).

Camera: requested only when the user chooses to photograph a finished cook for their on-device Cooking Journal.

Background modes: "fetch" checks dutchovendaddy.com for new posts to raise a local notification; "remote-notification" receives CloudKit change pushes for iCloud Sync.
```
