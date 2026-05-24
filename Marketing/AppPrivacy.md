# App Store Privacy Questionnaire — v1.0

**Status:** T-182 draft. Verify line-by-line against constitution §9 before submitting. Amended 2026-05-24 for CL-21 (comments + ratings, US-13/14/15).

When submitting v1.0 to App Store Connect, answer the **App Privacy** section exactly as below. Every claim here traces to a constitution clause; deviating requires a constitution amendment + a new audit.

## Top-level question: "Does this app collect data from this app?"

**Answer:** **Yes** — Usage Data, Contact Info (email), and User Content (comment text).

Rationale: we send TelemetryDeck events listed in `AnalyticsEvent.swift`. Although TelemetryDeck does not collect personal data, Apple's questionnaire counts any data sent off-device as "collected." Separately, v1.0 ships comments + ratings (US-13/14/15): when a user posts, the app sends their display name, email, and (for US-14) the comment body to dutchovendaddy.com's WordPress REST endpoints. **Name + email never reach TelemetryDeck** — they travel only to dutchovendaddy.com over HTTPS.

## Data Types Collected

Check **only** the following categories:

| Apple category | Specific type | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|---|
| Usage Data | Product Interaction | **No** | **No** | App Functionality, Analytics |
| Contact Info | Email Address | **Yes** (to the user's chosen display name) | **No** | App Functionality |
| User Content | Customer Support | **Yes** | **No** | App Functionality |

Everything else (Health & Fitness, Financial Info, Location, Sensitive Info, Contacts, Browsing History, Search History, Identifiers, Purchases, Diagnostics) — **uncheck**.

### "Contact Info — Email Address" details

- Collected only when a user posts a rating (US-13) or comment (US-14) for the first time.
- Stored on-device in the iOS Keychain under service `com.dutchovendaddy.DODApp.guest` so the user isn't re-prompted on subsequent posts (US-15 AC-15.2).
- Sent over HTTPS to `https://www.dutchovendaddy.com/wp-json/wp/v2/comments` and `https://www.dutchovendaddy.com/wp-json/wp-recipe-maker/v1/rating` as the standard WordPress `author_email` field for moderation.
- **Never** sent to TelemetryDeck or any third party.

### "User Content — Customer Support" details

- The comment body text the user submits in US-14's composer.
- Sent over HTTPS to `https://www.dutchovendaddy.com/wp-json/wp/v2/comments`.
- **Never** sent to TelemetryDeck. The `recipeCommentSubmitted` analytics event carries only the integer recipe id and a bool for moderation status — never the raw comment body (constitution §9, spec AC-14.7).

### "Product Interaction" details

When asked which interactions:

- Tap events on tabs and recipe items
- Save / unsave actions
- Search submissions (the **query is hashed** before transmission — see constitution §9 and spec AC-3.6)
- Share-sheet invocations
- Offline-read events on saved recipes

### "Linked to user" — answer No, because:

- No accounts, no sign-in.
- TelemetryDeck assigns an anonymous client hash; we never send IDFA, IDFV, email, phone, or any identifier that ties to a real person.
- The hashed search query is one-way; you cannot recover the original text from the hash.

### "Used for tracking" — answer No, because:

- We do not link the data with third-party data for advertising/measurement.
- We do not share with data brokers.
- We do not use the data to target advertising in our app or any other (we run no ads at all).

## Privacy Policy URL

You must host a privacy policy at a stable URL and link it in App Store Connect. Suggested boilerplate (verify with a lawyer before publishing):

```
Dutch Oven Daddy iOS App — Privacy Policy

The Dutch Oven Daddy iOS app collects anonymous Usage Data via TelemetryDeck
(https://telemetrydeck.com) for the sole purpose of understanding which
features of the app are used. No account is required. We do not share, sell,
or rent any data. Search queries are cryptographically hashed before
transmission so the original text cannot be recovered. Saved recipes are
stored only on your device.

When you post a comment or rating, your display name and email are sent to
dutchovendaddy.com so the comment can be moderated and replied to. We do not
share this with anyone else. Your display name and email are stored on your
device in the iOS Keychain so you don't have to re-enter them; uninstalling
the app removes them.

For questions, contact: <support@dutchovendaddy.com>

Last updated: <YYYY-MM-DD>
```

Host this at `https://www.dutchovendaddy.com/app-privacy/` (or similar) and paste the URL into App Store Connect → App Privacy → Privacy Policy URL.

## ATT (App Tracking Transparency) prompt

**Not used.** TelemetryDeck does not require an ATT prompt because it does not access IDFA. If you ever add an SDK that does (e.g. Google Analytics), this becomes a required prompt before any tracking call — and triggers a constitution amendment.

## What changes for v2

If you add CloudKit sync for saved recipes (v2):

- Add **Identifiers — Device ID** (if iCloud requires it) to the Data Types table.
- Re-answer the linkage question: probably **Linked to user** = Yes because iCloud is per-Apple-ID.

If you add push notifications for new recipes:

- Add **Identifiers — Device ID** (APNs token).
- Update the purposes column to include "Notifications."
