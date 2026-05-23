# App Store Privacy Questionnaire — v1.0

**Status:** T-182 draft. Verify line-by-line against constitution §9 before submitting.

When submitting v1.0 to App Store Connect, answer the **App Privacy** section exactly as below. Every claim here traces to a constitution clause; deviating requires a constitution amendment + a new audit.

## Top-level question: "Does this app collect data from this app?"

**Answer:** **Yes** — Usage Data only.

Rationale: we send TelemetryDeck events listed in `AnalyticsEvent.swift`. Although TelemetryDeck does not collect personal data, Apple's questionnaire counts any data sent off-device as "collected."

## Data Types Collected

Check **only** the following categories:

| Apple category | Specific type | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|---|
| Usage Data | Product Interaction | **No** | **No** | App Functionality, Analytics |

Everything else (Contact Info, Health & Fitness, Financial Info, Location, Sensitive Info, Contacts, User Content, Browsing History, Search History, Identifiers, Purchases, Diagnostics) — **uncheck**.

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
features of the app are used. No personal information is collected. No
account is required. We do not share, sell, or rent any data. Search
queries are cryptographically hashed before transmission so the original
text cannot be recovered. Saved recipes are stored only on your device.

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
