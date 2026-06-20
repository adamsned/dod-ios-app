# Sign in with Apple revoke Worker (DUT-98 / T-797)

A tiny **stateless** Cloudflare Worker that lets the DOD iOS app satisfy **App
Store Review Guideline 5.1.1(v)**: deleting your account must **revoke the Sign
in with Apple token**. There is no pure-client way — Apple's `/auth/token` and
`/auth/revoke` require a server-signed `client_secret`. This Worker holds the
Sign in with Apple private key and exposes two operations:

| Endpoint | When | Request | Response |
|----------|------|---------|----------|
| `POST /exchange` | once at sign-in | `{ "code": "<authorizationCode>" }` | `{ "refreshToken": "..." }` |
| `POST /revoke` | on Delete Account | `{ "refreshToken": "..." }` | `{ "revoked": true }` |

Every request must send `X-DOD-App-Key: <APP_SHARED_SECRET>` (same shared-secret
gate the WP comment endpoint uses). The Worker stores nothing — the app keeps
the refresh token in its Keychain session.

## One-time Apple setup (owner)

1. **Create a Sign in with Apple Key** at <https://developer.apple.com/account/resources/authkeys/list>:
   - Keys → ＋ → name it (e.g. "DOD SiwA Revoke"), enable **Sign in with Apple**, configure it to the primary App ID `com.dutchovendaddy.DODApp`, Register, **Download the `.p8`** (one-time download).
   - Note the **Key ID** (10 chars) and your **Team ID** (top-right of the portal).
   - *(This Key is separate from the "Sign in with Apple" capability you already enabled on the App ID — the capability lets the app sign in; the Key lets the server sign the `client_secret`.)*

## Deploy

```bash
cd backend/siwa-revoke
npm install
# fill APPLE_KEY_ID + APPLE_TEAM_ID in wrangler.toml (APPLE_CLIENT_ID is already the bundle id)
npx wrangler deploy
# then set the two secrets (encrypted, never committed):
npx wrangler secret put APPLE_PRIVATE_KEY   # paste the full .p8 file contents (incl. BEGIN/END lines)
npx wrangler secret put APP_SHARED_SECRET   # a long random string — also goes in the iOS app config
```

`wrangler deploy` prints the Worker URL (e.g. `https://dod-siwa-revoke.<you>.workers.dev`). Put that URL + the `APP_SHARED_SECRET` into the iOS app's `SiwaRevokeConfig` (see `Packages/DODSupport/.../SiwaRevokeClient.swift`).

## Test it (after deploy)

```bash
# revoke with a junk token should reach Apple and come back non-200 (proves wiring + auth):
curl -sS -X POST https://dod-siwa-revoke.<you>.workers.dev/revoke \
  -H "X-DOD-App-Key: $APP_SHARED_SECRET" -H "Content-Type: application/json" \
  -d '{"refreshToken":"not-a-real-token"}'
# -> {"revoked":false,"appleStatus":400}   (400 from Apple = the client_secret JWT was accepted)
# A missing/incorrect X-DOD-App-Key returns 401 before Apple is ever called.
```

The real end-to-end path (exchange a live authorization code, then revoke) is exercised by the app's Delete Account flow on a device.

## How it works

`makeClientSecret()` builds an **ES256 JWT** (`iss=teamId`, `aud=https://appleid.apple.com`, `sub=clientId`, `kid=keyId`, 5-min expiry) and signs it with the `.p8` via WebCrypto (`ECDSA P-256`). `/exchange` POSTs `grant_type=authorization_code` to `/auth/token`; `/revoke` POSTs the refresh token to `/auth/revoke`. No state, no database.
