// Dutch Oven Daddy — Grocery order Worker (DUT-532).
//
// A tiny STATELESS Cloudflare Worker that turns a recipe's ingredient list into
// a one-tap grocery-ordering link, WITHOUT the app ever holding a vendor key.
// The app sends the ingredients; this Worker holds the grocery-vendor secrets
// (as encrypted secrets) and returns a `products_link_url` the app opens in a
// browser / SFSafariViewController.
//
//   POST /   { "provider": "instacart" | "walmart_plus",
//              "title": "...",
//              "line_items": [{ "name", "quantity?", "unit?", "display_text?" }],
//              "landing_page_configuration?": { "partner_linkback_url?" } }
//         -> { "products_link_url": "https://..." }
//
// Providers:
//   • instacart    — LIVE. Calls the Instacart IDP "products_link" endpoint with
//                    a server-held API key; Instacart builds the shopping list.
//   • walmart_plus — SEARCH-LINK FALLBACK. We have no approved Walmart cart API,
//                    so we build a Walmart grocery *search* URL from the
//                    ingredient names (optionally affiliate-tagged). See the
//                    TODO(walmart-api) block for the future add-to-cart path.
//
// Stateless by design: the Worker stores nothing. This mirrors the sibling
// `backend/siwa-revoke` Worker (DUT-98) — same X-DOD-App-Key gate, same
// request/response shape, same tooling.
//
// Every request must carry `X-DOD-App-Key: <DOD_APP_KEY>` — the same
// shared-secret gate the SIWA revoke + WordPress comment endpoints use — so the
// endpoint isn't an open relay. Native apps don't trigger CORS preflight, but
// we answer OPTIONS + send permissive CORS so a future web caller works too.

export interface Env {
  DOD_APP_KEY: string // shared gate; the app sends it as X-DOD-App-Key. Set via `wrangler secret put`.
  INSTACART_API_KEY: string // Instacart IDP API key (Bearer). Set via `wrangler secret put`.
  INSTACART_BASE_URL?: string // defaults to prod; set to the sandbox host for the sandbox key.
  WALMART_AFFILIATE_ID?: string // optional Impact/affiliate id appended to the fallback search URL.
  // WALMART_API_KEY?: string   // FUTURE (walmart-api): unlocks the real add-to-cart path. Not used yet.
}

const INSTACART_DEFAULT_BASE_URL = "https://connect.instacart.com"
const INSTACART_PRODUCTS_LINK_PATH = "/idp/v1/products/products_link"

// Input caps — keep payloads sane and avoid abusing the vendor APIs.
const MAX_LINE_ITEMS = 100
const MAX_TITLE_LEN = 200
const MAX_NAME_LEN = 200
const UPSTREAM_TIMEOUT_MS = 10_000

const KNOWN_PROVIDERS = ["instacart", "walmart_plus"] as const
type Provider = (typeof KNOWN_PROVIDERS)[number]

interface LineItem {
  name: string
  quantity?: number
  unit?: string
  display_text?: string
}

interface OrderRequest {
  provider?: string
  title?: string
  image_url?: string
  line_items?: LineItem[]
  landing_page_configuration?: { partner_linkback_url?: string }
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-DOD-App-Key",
  "Access-Control-Max-Age": "86400",
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS })
    }
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405)
    }
    if (request.headers.get("X-DOD-App-Key") !== env.DOD_APP_KEY) {
      return json({ error: "unauthorized" }, 401)
    }

    try {
      const body = (await request.json().catch(() => ({}))) as OrderRequest
      const parsed = validate(body)
      if ("error" in parsed) {
        return json({ error: parsed.error }, 400)
      }

      if (parsed.provider === "instacart") {
        return await handleInstacart(parsed, env)
      }
      return handleWalmartPlus(parsed, env)
    } catch (err) {
      // Never leak key material / internals to the client.
      return json({ error: "server_error", detail: String((err as Error).message) }, 500)
    }
  },
}

// MARK: - validation

interface ValidRequest {
  provider: Provider
  title: string
  image_url?: string
  line_items: LineItem[]
  landing_page_configuration?: { partner_linkback_url?: string }
}

function validate(body: OrderRequest): ValidRequest | { error: string } {
  if (!body.provider || !KNOWN_PROVIDERS.includes(body.provider as Provider)) {
    return { error: "unknown_provider" }
  }
  const title = (body.title ?? "").trim()
  if (!title) return { error: "missing_title" }
  if (title.length > MAX_TITLE_LEN) return { error: "title_too_long" }

  const items = body.line_items
  if (!Array.isArray(items) || items.length === 0) {
    return { error: "empty_line_items" }
  }
  if (items.length > MAX_LINE_ITEMS) return { error: "too_many_line_items" }

  const line_items: LineItem[] = []
  for (const raw of items) {
    const name = (raw?.name ?? "").trim()
    if (!name) return { error: "line_item_missing_name" }
    if (name.length > MAX_NAME_LEN) return { error: "line_item_name_too_long" }
    const item: LineItem = { name }
    if (typeof raw.quantity === "number" && raw.quantity > 0) item.quantity = raw.quantity
    if (typeof raw.unit === "string" && raw.unit.trim()) item.unit = raw.unit.trim()
    if (typeof raw.display_text === "string" && raw.display_text.trim()) {
      item.display_text = raw.display_text.trim()
    }
    line_items.push(item)
  }

  return {
    provider: body.provider as Provider,
    title,
    image_url: typeof body.image_url === "string" ? body.image_url : undefined,
    line_items,
    landing_page_configuration: body.landing_page_configuration,
  }
}

// MARK: - instacart (LIVE)

async function handleInstacart(req: ValidRequest, env: Env): Promise<Response> {
  if (!env.INSTACART_API_KEY) {
    return json({ error: "provider_unavailable", provider: "instacart" }, 502)
  }
  const base = (env.INSTACART_BASE_URL || INSTACART_DEFAULT_BASE_URL).replace(/\/+$/, "")
  const endpoint = `${base}${INSTACART_PRODUCTS_LINK_PATH}`

  // Exactly the IDP "products_link" body shape. `link_type: shopping_list` tells
  // Instacart to build a shopping-list landing page from these line_items.
  const idpBody = {
    title: req.title,
    image_url: req.image_url,
    link_type: "shopping_list",
    line_items: req.line_items,
    landing_page_configuration: req.landing_page_configuration,
  }

  let resp: Response
  try {
    resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.INSTACART_API_KEY}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(idpBody),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    })
  } catch {
    // Timeout / network error — never echo internals.
    return json({ error: "provider_unreachable", provider: "instacart" }, 502)
  }

  const data = (await resp.json().catch(() => ({}))) as { products_link_url?: string }
  if (!resp.ok || !data.products_link_url) {
    // Surface a SAFE message only — the Instacart key must never leak.
    return json({ error: "provider_error", provider: "instacart", status: resp.status }, 502)
  }
  return json({ products_link_url: data.products_link_url })
}

// MARK: - walmart_plus (SEARCH-LINK FALLBACK)

function handleWalmartPlus(req: ValidRequest, env: Env): Response {
  // No approved Walmart cart API — build a grocery *search* URL from the
  // ingredient names. Deep-links into Walmart's grocery search so the user can
  // add items to their Walmart+ cart. Works with ZERO Walmart credentials.
  //
  // TODO(walmart-api): once a WALMART_API_KEY (Walmart.io) is approved, replace
  // this fallback with the real add-to-cart path:
  //   1. For each line_item, call Walmart.io Product Search
  //      (`https://developer.api.walmart.com/api-proxy/service/affil/product/v2/search?query=<name>`)
  //      with the signed WALMART_API_KEY headers to resolve an item id.
  //   2. Build an affiliate cart deep link:
  //      `https://affil.walmart.com/cart/addToCart?items=<id>_<qty>,<id>_<qty>,...`
  //   3. Return that as `products_link_url` (so the app path is unchanged).
  // Gate the whole block on `env.WALMART_API_KEY` being present; fall back to
  // the search URL below when it isn't. Do NOT implement the Product Search call
  // until access is approved.

  const query = req.line_items.map((it) => it.name).join(", ")
  const url = new URL("https://www.walmart.com/search")
  url.searchParams.set("q", query)
  if (env.WALMART_AFFILIATE_ID) {
    // Impact/affiliate attribution param.
    url.searchParams.set("affiliateId", env.WALMART_AFFILIATE_ID)
  }
  return json({ products_link_url: url.toString() })
}

// MARK: - helpers

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  })
}
