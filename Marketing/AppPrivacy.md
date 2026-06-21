# App Store Privacy Questionnaire — v1.0

**Status:** T-182 draft. Verify line-by-line against constitution §9 before submitting. Amended 2026-05-24 for CL-21 (comments + ratings, US-13/14/15). Amended 2026-05-28 for CL-94 + CL-95 + CL-96 (CloudKit private-DB sync, US-41 / T-700..T-708) — see the new "What changes for v1.x (CloudKit sync)" section below.

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

## What changes for v1.x (CloudKit sync — US-41 / T-700..T-708, 2026-05-28)

**Status:** This section was added by the T-700 spec amendment per CL-94 + CL-95 + CL-96. The previous "What changes for v2 / If you add CloudKit sync for saved recipes (v2)" speculation block is preserved below under the strike-through "Historical speculation (superseded)" subhead — it incorrectly speculated that CloudKit sync would require an "Identifiers — Device ID" disclosure and a "Linked to user — Yes" answer. Per Apple's own App Privacy guidance for CloudKit private-DB-only usage, neither is required.

### Question: "Did you make changes to your privacy practices?" (App Store Connect → App Privacy)

**Answer:** **No** for the data-categories table; **Yes** for the analytics-event list (the four new sync events from CL-96 are added to constitution §9's allowlist but fall under the existing "Usage Data — Product Interaction" row, so the questionnaire's category-level answer is "No new categories"). When submitting the build that turns on CloudKit sync, the privacy section requires no structural change to the existing table — only the constitution §9 allowlist gets the four event names appended (paired with T-707).

### Why no new data category to declare

Apple's App Privacy guidance at https://developer.apple.com/app-store/app-privacy-details/ explicitly says: **"If your app uses CloudKit and only sends data to the user's own CloudKit container, you do not need to disclose the data as collected by your app."** Our CloudKit usage is private-database-only (per CL-88's enumerated scope + REG-25's lock on no-public / no-shared / no-Discoverability) — saved recipes mirror to the user's own iCloud private database under `iCloud.com.dutchovendaddy.DODApp`, accessible only to the user on Apple devices signed into their Apple ID. The data is user-to-Apple, not user-to-us; we don't see it, collect it, or have any access to it.

The same pattern applies to iCloud Photos, iCloud Drive, iCloud Keychain, iCloud Notes — none of them disclose synced data as "collected." Our App Privacy questionnaire follows the same Apple-published pattern.

### The four new analytics events (per CL-96)

Constitution §9's "Events tracked are limited to:" sentence is amended (paired with T-707) to add four new closed-enum event names, all falling under the existing "Usage Data — Product Interaction" row in the questionnaire:

| Event | Payload | Where dispatched |
|---|---|---|
| `syncEnabled` | empty | AC-41.2 opt-in primary tap; AC-41.3 toggle on |
| `syncDisabled` | empty | AC-41.3 toggle off (after the AC-41.5 confirmation alert) |
| `syncCompletedSuccessfully` | empty | After a successful CloudKit round-trip; debounced to fire at most once per 60 seconds |
| `syncFailed(errorCategory:)` | `errorCategory: SyncErrorCategory` (closed enum: `network` / `accountStatus` / `quotaExceeded` / `serverInternal` / `other`) | After retry-budget exhaustion (3 consecutive failures per AC-41.6) |

**Why allowlist-safe.** All four events are device-state aggregates with no PII, no recipe IDs, no error messages, no device identifiers. The `errorCategory` payload is a closed-set enum (five values total) — the same posture as `widgetOpened.kind` ("featured" / "saved") and `voiceCommandFired.command` ("next" / "previous" / "repeat" / "pause"), both already on the allowlist. The raw `CKError.Code` (which has ~30 values + localized message strings) is **never** sent — only the five-bucket aggregation.

### Apple review template (if questioned)

If App Store review questions the "No new privacy disclosure" claim for the build that turns on CloudKit sync:

> The app uses CloudKit private database for cross-device sync of the user's saved recipes. Per Apple's App Privacy guidance for CloudKit private-DB-only usage, data sent only to the user's own CloudKit container is not disclosed as collected by the app. The container is `iCloud.com.dutchovendaddy.DODApp`; only `CKContainer.privateCloudDatabase` is accessed (no public DB, no shared DB, no Discoverability API). The four new analytics events fall under the existing Usage Data — Product Interaction row already disclosed; no IDFA, no device ID, no Apple ID, no email — the user remains anonymous to us in every analytics surface. The app works fully without iCloud sign-in per App Store Review Guideline 5.1.1(ii); the AC-41.5 Settings toggle-off + iCloud-sign-out paths fully remove the app's data from the user's iCloud space per 5.1.1(v) interpretation for CloudKit-using apps that do not create accounts.

This response template was adopted by 1Password (CloudKit + WebDAV) and Bear (CloudKit) for the same policy interpretation; the standard response pattern stands.

### The TestFlight gate (per CL-95 + AC-41.12)

The build that turns on CloudKit sync MUST NOT submit to TestFlight before the privacy policy at `https://www.dutchovendaddy.com/app-privacy/` contains the new "Optional iCloud Sync" paragraph from CL-95 (verbatim text below). This is a one-time gate; once the policy is live, the gate is satisfied for all subsequent builds.

**Paragraph to paste into the existing privacy policy at `dutchovendaddy.com/app-privacy/`** (between "Saved recipes are stored only on your device" and the comments/ratings paragraph):

> **Optional iCloud Sync.** When you enable iCloud Sync in Settings, the Dutch Oven Daddy app stores your saved recipes in your own iCloud private database under the container `iCloud.com.dutchovendaddy.DODApp`. The synced data — recipe titles, ingredients, instructions, hero image URLs, and the saved-state flag — is stored in your personal iCloud space and is accessible only to you, on Apple devices signed into the same Apple ID. We do not see, collect, or have any access to your iCloud data. To stop syncing, turn off iCloud Sync in Settings or sign out of iCloud entirely — either action removes your saved recipes from your iCloud space (your local saves on the device are preserved). The app continues to work fully without iCloud sync — you can browse, save, share, and cook recipes without signing into iCloud.

### Historical speculation (superseded)

The original "What changes for v2 / If you add CloudKit sync" speculation, written when CloudKit sync was a v2 deferred item per CL-5, incorrectly anticipated that CloudKit would require new data-collection disclosures. CL-86's pivot brings CloudKit into v1.x and CL-94 documents the correct App Privacy framing — no new category. The original wording is preserved as strike-through historical context so a future reader can see why the questionnaire reading changed:

- ~~Add **Identifiers — Device ID** (if iCloud requires it) to the Data Types table.~~ *Not required — `CKContainer.accountStatus(completionHandler:)` returns only an opaque `CKAccountStatus` enum; we never see the user's Apple ID, iCloud email, or any device identifier beyond TelemetryDeck's anonymous client hash.*
- ~~Re-answer the linkage question: probably **Linked to user** = Yes because iCloud is per-Apple-ID.~~ *Not required — the Usage Data row stays "No, not linked to user" because the four new sync events carry no user identifier (they're per-session device state); the Contact Info row stays "Yes, linked to user" because guest identity hasn't changed.*

If you add push notifications for new recipes (still deferred to a future US — not part of US-41):

- Add **Identifiers — Device ID** (APNs token).
- Update the purposes column to include "Notifications."

## What changes for Sign in with Apple (US-46 / DUT-16, 2026-06-20)

**Status:** Added for the build that ships **Sign in with Apple** (US-46 / AC-46.6, CL-191, T-797) — the **optional** login that sits alongside guest mode (guest stays the default per App Store 5.1.1(ii); no one is ever forced to sign in). This section is the App Privacy delta for that build. *It is irrelevant to the guest-only release, which ships unchanged.*

### Question: "Did you make changes to your privacy practices?" (App Store Connect → App Privacy)

**Answer for the data-categories table: No new categories.** Sign in with Apple is a **new way to obtain the same Contact Info** the app already declares (email + name), not a new data type:

- **Contact Info — Email Address** (already in the v1.0 table). When a user signs in with Apple and shares their email, the app receives it — which may be an Apple **private-relay** address (`…@privaterelay.appleid.com`) if they chose "Hide My Email." A relay address is still an email → it stays in the existing **Contact Info — Email Address** row (**Linked to user = Yes, Used for tracking = No**). As before, the email travels only to dutchovendaddy.com when the user posts a comment/rating — **never to TelemetryDeck**.
- **Contact Info — Name** (the display name). Confirm this row is present (it backs the comment/rating author name and the signed-in identity row). **Linked = Yes, Tracking = No.** Purpose: App Functionality.

**No new category to add — and specifically NOT these:**

- **Identifiers — User ID:** the Apple `userIdentifier` is stored **on-device only** (Keychain, device-local per DUT-30) — never transmitted to a third party, never used to track across apps/companies. On-device-only data is not "collected" per Apple's definition → do **not** declare it.
- The **authorization code / refresh token** exchanged with the revoke Worker (below) are **authentication artifacts**, not a declarable user-data type. The only declarable data in the SiwA flow is the email/name, already covered.

### The revoke Worker (Cloudflare) — a first-party auth processor

To satisfy **5.1.1(v)** (account deletion must revoke the Apple token), the app talks to a small first-party Cloudflare Worker (`backend/siwa-revoke/`) that exchanges the sign-in authorization code for a refresh token and revokes it on deletion. It is **stateless** — it stores nothing; the app holds the refresh token in its Keychain. It processes **authentication tokens only — no user content, no analytics, no tracking**. It is **not** a third-party analytics/advertising SDK, so it adds **no** new App Privacy disclosure. (If you ever make it stateful — storing user records server-side — revisit this section.)

### "Used for tracking" — still **No**

No IDFA, no cross-app/cross-company tracking, no data broker. Sign in with Apple authenticates the user to *this* app only. **ATT prompt: still not used.**

### Apple review template (if questioned about Sign in with Apple)

> Sign in with Apple is optional — the app is fully usable as a guest (App Store Review Guideline 5.1.1(ii)). When a user signs in, the app receives the Apple user identifier (stored only on-device, in the Keychain) and, if the user shares them, their name and email (which may be an Apple private-relay address). The name/email are used only for the in-app identity and to attribute the user's own comments/ratings on dutchovendaddy.com; they are never sent to any analytics provider. **Account deletion (Settings → Account → Delete Account) revokes the Sign in with Apple token** via a first-party stateless Cloudflare Worker that calls Apple's `/auth/revoke`, so the app is removed from the user's Settings → Apple ID → Sign in with Apple list (5.1.1(v)). The Worker stores no user data. No IDFA, no device ID, no cross-app tracking.

### Privacy-policy paragraph to add at `dutchovendaddy.com/app-privacy/`

Paste alongside the comments/ratings + iCloud-Sync paragraphs (a one-time gate, like CL-95's):

> **Optional Sign in with Apple.** You can use Dutch Oven Daddy without an account. If you choose to sign in with Apple, we receive your Apple user identifier (kept only on your device) and, if you choose to share them, your name and email — which may be an Apple private-relay address if you select "Hide My Email." We use these only to show who you're signed in as and to attribute comments or ratings you post; we never share them with advertisers or analytics. When you delete your account in the app, we revoke your Sign in with Apple token so the app is removed from your Apple ID's "Sign in with Apple" list. You can sign out at any time to return to browsing as a guest.
