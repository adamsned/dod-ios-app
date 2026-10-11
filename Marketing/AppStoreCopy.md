# App Store Marketing Copy — v1.0

**Status:** updated 2026-10-11. The promotional text, description, keywords, URLs and review notes below are what is saved on the 1.0 version page in App Store Connect; each claim was checked against `main`.

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
Step-by-step Cook Mode, a charcoal Heat Coach, and cast-iron seasoning tips for dutch oven and campfire cooking. No account required to browse, save, or cook.
```

## Description (max 4000 chars)

```
Dutch Oven Daddy turns your iPhone or iPad into a cast-iron cooking companion: recipes, timers, and coaching built for the fire, the campsite, and the kitchen.

COOK WITH CONFIDENCE
Step-by-step Cook Mode keeps your hands free and your place in the recipe, with a built-in timer for every step, Live Activity + Dynamic Island support so your timer follows you off-screen, and a Heat Coach that helps you dial in your charcoal briquette count instead of guessing.

BUILT FOR REAL CAST-IRON COOKING
Browse a growing catalog of dutch oven, cast iron skillet, and campfire recipes. Save your favorites, build a shopping list that groups ingredients by aisle, and adjust servings with automatic quantity scaling. Metric or imperial, your choice.

LEARN TO SEASON AND CARE FOR YOUR CAST IRON
New to cast iron? Guided tips walk you through seasoning, cleaning, and caring for your cookware so it lasts a lifetime. No guesswork, no ruined pans.

YOUR COOKING, YOUR WAY
No account required to browse, save, or cook. Set up a profile, or sign in with Apple or Google, only if you want to rate recipes or join the conversation in comments. Track what you've cooked in a private Cooking Journal that stays on your device, and keep your saved recipes in sync across your devices with iCloud.

WHY DUTCH OVEN DADDY
Built by a lifelong Dutch oven and cast iron cook, for the community that gathers around the campfire. No clutter, no noise, just the tools you need to cook like you've been doing it for years.
```

## Keywords (max 100 chars total, comma-separated)

```
skillet,seasoning,charcoal,briquette,campfire,camping,bbq,outdoor,tips,guide,care,cookware
```

## What's New (release notes) for v1.0

```
Welcome to the Dutch Oven Daddy app! Browse, search, and save cast iron and Dutch oven recipes from dutchovendaddy.com, then cook them step by step with Cook Mode.
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://www.dutchovendaddy.com/contact-me/` |
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
No account, user name or password is needed to review the app. It opens straight to the recipe feed and every feature works as a guest.

Rating or commenting on a recipe shows "Set Up Your Profile". Enter any display name and email to continue. The profile is stored only on the device: there is no password, no verification email and no server account, so there is no demo account to provide. Sign in with Apple and Sign in with Google are optional alternatives and can be tested with any Apple or Google account.

Account deletion (5.1.1(v)): open the profile and tap Delete Profile. This erases the profile and sign-in details from the device and revokes the Sign in with Apple token through a first-party, stateless Cloudflare Worker that calls Apple's /auth/revoke. Google sign-in is disconnected the same way.

User-generated content (1.2): recipe comments are posted to and moderated on dutchovendaddy.com. In the app, tap a commenter or long-press a comment to Report Comment or Block the author. Contact: daddy@dutchovendaddy.com, also reachable from Settings → Contact Support.

Privacy (5.1.1): Settings → Data & Privacy has the Privacy Policy link, a Privacy Dashboard showing where each kind of data lives, Export My Data, and the switch that turns off anonymous usage data.

iCloud: optional. Saved recipes sync through the user's private CloudKit database only (no public or shared database).

Camera: requested only when the user chooses to photograph a finished cook for their on-device Cooking Journal.

Background modes: "fetch" checks dutchovendaddy.com for new posts to raise a local notification; "remote-notification" receives CloudKit change pushes for iCloud Sync.
```
