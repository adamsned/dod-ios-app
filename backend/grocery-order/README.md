# Grocery order Worker (DUT-532)

A tiny **stateless** Cloudflare Worker that turns a recipe's ingredient list into
a one-tap grocery-ordering link — **without the app ever holding a vendor key**.
The app POSTs the ingredients; this Worker holds the grocery-vendor secrets and
returns a `products_link_url` the app opens in a browser. It mirrors the sibling
`backend/siwa-revoke` Worker (DUT-98): same `X-DOD-App-Key` gate, same
request/response shape, same tooling.

| Endpoint | Request | Response |
|----------|---------|----------|
| `POST /` | `{ "provider", "title", "line_items": [{ "name", "quantity?", "unit?", "display_text?" }], "landing_page_configuration?": { "partner_linkback_url?" } }` | `{ "products_link_url": "https://..." }` |

Every request must send `X-DOD-App-Key: <DOD_APP_KEY>` (same shared-secret gate the
SIWA revoke + WP comment endpoints use). The Worker stores nothing.

## Providers

| `provider` | Status | How the link is built |
|------------|--------|-----------------------|
| `instacart` | **LIVE** | POSTs to the Instacart IDP `products_link` endpoint (`link_type: shopping_list`) with a server-held Bearer key; Instacart builds the shopping-list page. |
| `walmart_plus` | **Search fallback** | No approved Walmart cart API, so we build a Walmart grocery **search URL** from the ingredient names (optionally affiliate-tagged). Works with **zero** Walmart credentials. |

The Walmart add-to-cart path (resolve each ingredient → Walmart item id via
Walmart.io Product Search → `affil.walmart.com/cart/addToCart?items=<id>_<qty>,…`)
is left as a clearly-marked `TODO(walmart-api)` in `src/index.ts`, gated on a
future `WALMART_API_KEY` secret. Do not implement it until access is approved.

## Secrets & config

| Name | Where | Purpose |
|------|-------|---------|
| `DOD_APP_KEY` | `wrangler secret put` | shared gate; the app sends it as `X-DOD-App-Key`. |
| `INSTACART_API_KEY` | `wrangler secret put` | Instacart IDP API key (Bearer). |
| `INSTACART_BASE_URL` | `wrangler.toml [vars]` | `https://connect.instacart.com` (prod) **or** `https://connect.dev.instacart.tools` (sandbox). Defaults to prod if unset. |
| `WALMART_AFFILIATE_ID` | `wrangler.toml [vars]` (optional) | appended to the fallback search URL when set. |
| `WALMART_API_KEY` | *future* | not used yet; unlocks the add-to-cart path. |

### Instacart sandbox vs prod

Set `INSTACART_BASE_URL` to match the **key** you set as `INSTACART_API_KEY`:

- Sandbox key → `INSTACART_BASE_URL = "https://connect.dev.instacart.tools"`
- Production key → `INSTACART_BASE_URL = "https://connect.instacart.com"` (the default)

## Deploy

**One-liner:** `cd backend/grocery-order && ./deploy.sh` — it installs, prompts
you to fill `wrangler.toml`, deploys, and sets the secrets interactively.
(`npx wrangler login` once first.) Or do it manually:

```bash
cd backend/grocery-order
npm install
# set INSTACART_BASE_URL in wrangler.toml (prod host, or the sandbox host for a sandbox key)
npx wrangler deploy
# then set the secrets (encrypted, never committed):
npx wrangler secret put DOD_APP_KEY        # a long random string — also goes in the iOS app config
npx wrangler secret put INSTACART_API_KEY  # the Instacart IDP API key
# optional: put WALMART_AFFILIATE_ID under [vars] in wrangler.toml
```

`wrangler deploy` prints the Worker URL (e.g. `https://dod-grocery-order.<you>.workers.dev`).

## Test it (after deploy)

```bash
# Walmart fallback needs NO vendor key — proves wiring + the app-key gate:
curl -sS -X POST https://dod-grocery-order.<you>.workers.dev/ \
  -H "X-DOD-App-Key: $DOD_APP_KEY" -H "Content-Type: application/json" \
  -d '{"provider":"walmart_plus","title":"Chili","line_items":[{"name":"onion"}]}'
# -> {"products_link_url":"https://www.walmart.com/search?q=onion"}
# A missing/incorrect X-DOD-App-Key returns 401 before anything else runs.
```

The Instacart path is exercised end-to-end from the app once a live key is set.
Local logic (app-key guard, validation, IDP body mapping, happy-path passthrough,
Walmart fallback + affiliate param) is covered by `npm test` (Node's built-in
test runner against a mocked upstream `fetch`).

## Final app step (the app is dormant until this is done)

Like the SIWA Worker / `GroceryOrderConfig` gate, the app does nothing until it's
pointed at a live Worker:

1. Paste the deployed Worker URL into the app's **`DODGroceryEndpoint`** config.
2. Set the shared **`X-DOD-App-Key`** in the app to the **same** value as the
   Worker's `DOD_APP_KEY` secret.
3. Enable the providers you want in **`DODGroceryProviders`** (`instacart` and/or
   `walmart_plus`).

Until then the feature stays dormant (no endpoint = no order button), exactly as
the SIWA flow stays dormant until `SiwaRevokeConfig` is filled in.

## How it works

The Worker validates the app's body (known provider, non-empty `line_items`,
sane caps), then branches on `provider`. For `instacart` it maps the body 1:1 to
the IDP `products_link` body (`link_type: "shopping_list"`), POSTs it with
`Authorization: Bearer <INSTACART_API_KEY>`, and returns the
`products_link_url`; upstream failures come back as a **safe 502** that never
echoes the key. For `walmart_plus` it builds a `walmart.com/search?q=<names>` URL
(plus `affiliateId` when configured) with no upstream call. No state, no database.
