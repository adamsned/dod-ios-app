# App Store Privacy Questionnaire — v1.0

**Status:** rewritten 2026-10-11 against `main` @ `123ebabf`. These answers describe what the code on `main` sends off the device today. `App/PrivacyInfo.xcprivacy` declares the same five data types; change both together. Earlier revisions of this file (TelemetryDeck-only, "no accounts") are in git history.

## "Does this app collect data?"

**Yes.**

## Data types

Tick only these five. "Collected" in Apple's sense means sent off the device and kept longer than it takes to answer the request.

| Category → type | Linked to user | Tracking | Purpose | What it is |
|---|---|---|---|---|
| Contact Info → **Name** | Yes | No | App Functionality | Display name sent to dutchovendaddy.com with a comment or rating. |
| Contact Info → **Email Address** | Yes | No | App Functionality | Email sent with a comment or rating, for moderation. May be an Apple private-relay address. |
| User Content → **Other User Content** | Yes | No | App Functionality | Comment text and star ratings, published on the recipe. |
| Usage Data → **Product Interaction** | No | No | Analytics | Recipe/article opens mirrored to Google Analytics 4 (`GA4Transport`). |
| Identifiers → **Device ID** | No | No | Analytics | The GA4 `client_id`: a salted SHA-256 of `identifierForVendor`. Hashed, but still a device-level ID. |

Both analytics rows are off when the user turns off Settings → Data & Privacy → Share Anonymous Usage Data.

## Not collected

| Type | Why not |
|---|---|
| Identifiers → User ID | The Apple and Google user identifiers are stored on the device only (Keychain). |
| User Content → Photos or Videos | Journal, profile, and cook photos stay on the device. |
| Search History | Queries go to dutchovendaddy.com only to return results. **Judgment call:** if the site ever analyses or retains search queries beyond ordinary short-lived server logs, declare this (not linked, App Functionality). |
| Diagnostics | No crash or performance SDK. |
| Location, Contacts, Health, Financial, Sensitive Info, Browsing History, Purchases | Not accessed. |
| Saved recipes in iCloud | Private CloudKit database only. Apple's guidance: data sent only to the user's own CloudKit container is not "collected". |

The Sign in with Apple authorization code and refresh token pass through the first-party revoke Worker (`backend/siwa-revoke`), which stores nothing. They are authentication artifacts, not a declarable data type.

## Tracking

**No**, and no ATT prompt. The app reads no IDFA, has no ad SDK, and does not combine its data with third-party data for advertising. Keep it that way in Google Analytics: do not enable Google Signals or link the GA4 property to an ads account for these events, or this answer has to be revisited.

## Privacy Policy URL

`https://www.dutchovendaddy.com/app-privacy/` — published text in `Marketing/PrivacyPolicy.md`. The in-app link (`SettingsViewModel.privacyPolicyURLString`) must point at the same page.

## Account deletion question

**Yes, the app offers account deletion**: profile → Delete Profile. It erases the on-device profile and session, revokes the Sign in with Apple token through the revoke Worker, and disconnects Google. Comments already posted stay on the website until the user emails a removal request (stated in the policy).

## What changes this

| If you ship… | Then… |
|---|---|
| Remote push for new recipes (DUT-1397) | Device ID gains the purpose **App Functionality** (the APNs token is registered with the push Worker). Add the push paragraph to the policy. |
| TelemetryDeck (set `TelemetryDeckAppID`; it is unset on `main`, so nothing is sent) | No new category: its events fall under Product Interaction and its hashed ID under Device ID. Add the TelemetryDeck paragraph to the policy. |
| iCloud profile sync (DUT-943) | Still the private database only, so no new category. |
| Any SDK that reads IDFA or shares data for advertising | Tracking becomes **Yes** and an ATT prompt is required. |
