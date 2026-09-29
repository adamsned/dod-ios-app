// Validates the Grocery order Worker's request handling (DUT-532) end to end
// against a mocked upstream `fetch`, so the app-key guard, input validation,
// the Instacart IDP body mapping, and the Walmart search-URL fallback are all
// pinned. Runs on Node 18+ (WebCrypto/fetch built in):
//   node --test backend/grocery-order/test/groceryOrder.test.mjs
//
// The Worker's default export is imported directly and driven with real
// `Request` objects, so a regression in the request/response contract fails
// here before it ever reaches Instacart or the app.
import assert from "node:assert/strict"
import { test, beforeEach, afterEach } from "node:test"

// Import the Worker under test. src/index.ts is plain ES2022 + WebCrypto/fetch;
// modern Node strips the TypeScript-only syntax on import, so we drive the real
// default export directly with `Request` objects (no build step, no re-impl).
const worker = (await import("../src/index.ts")).default

const APP_KEY = "test-shared-secret"
const INSTACART_KEY = "test-instacart-key"

function makeRequest(body, { appKey = APP_KEY, method = "POST" } = {}) {
  const headers = { "Content-Type": "application/json" }
  if (appKey !== null) headers["X-DOD-App-Key"] = appKey
  return new Request("https://worker.example/", {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  })
}

const baseEnv = () => ({
  DOD_APP_KEY: APP_KEY,
  INSTACART_API_KEY: INSTACART_KEY,
  INSTACART_BASE_URL: "https://connect.dev.instacart.tools",
})

let realFetch
beforeEach(() => {
  realFetch = globalThis.fetch
})
afterEach(() => {
  globalThis.fetch = realFetch
})

// MARK: - app-key guard

test("missing/mismatched X-DOD-App-Key returns 401 before any upstream call", async () => {
  let called = false
  globalThis.fetch = async () => {
    called = true
    return new Response("{}")
  }
  const noKey = await worker.fetch(makeRequest({ provider: "walmart_plus" }, { appKey: null }), baseEnv())
  assert.equal(noKey.status, 401)
  assert.deepEqual(await noKey.json(), { error: "unauthorized" })

  const wrongKey = await worker.fetch(makeRequest({ provider: "walmart_plus" }, { appKey: "nope" }), baseEnv())
  assert.equal(wrongKey.status, 401)
  assert.equal(called, false, "upstream fetch never called when unauthorized")
})

test("non-POST method is rejected 405; OPTIONS gets CORS 204", async () => {
  const get = await worker.fetch(makeRequest(undefined, { method: "GET" }), baseEnv())
  assert.equal(get.status, 405)

  const opt = await worker.fetch(new Request("https://worker.example/", { method: "OPTIONS" }), baseEnv())
  assert.equal(opt.status, 204)
  assert.equal(opt.headers.get("Access-Control-Allow-Methods"), "POST, OPTIONS")
})

// MARK: - input validation

test("unknown provider returns 400 unknown_provider", async () => {
  const resp = await worker.fetch(
    makeRequest({ provider: "kroger", title: "x", line_items: [{ name: "onion" }] }),
    baseEnv()
  )
  assert.equal(resp.status, 400)
  assert.deepEqual(await resp.json(), { error: "unknown_provider" })
})

test("empty line_items returns 400 empty_line_items", async () => {
  const resp = await worker.fetch(
    makeRequest({ provider: "instacart", title: "Chili", line_items: [] }),
    baseEnv()
  )
  assert.equal(resp.status, 400)
  assert.deepEqual(await resp.json(), { error: "empty_line_items" })
})

test("missing title returns 400 missing_title", async () => {
  const resp = await worker.fetch(
    makeRequest({ provider: "instacart", line_items: [{ name: "onion" }] }),
    baseEnv()
  )
  assert.equal(resp.status, 400)
  assert.deepEqual(await resp.json(), { error: "missing_title" })
})

test("line item without a name returns 400", async () => {
  const resp = await worker.fetch(
    makeRequest({ provider: "instacart", title: "x", line_items: [{ quantity: 2 }] }),
    baseEnv()
  )
  assert.equal(resp.status, 400)
  assert.deepEqual(await resp.json(), { error: "line_item_missing_name" })
})

// MARK: - instacart request mapping + happy path

test("instacart: outgoing IDP body shape + Bearer header are exact", async () => {
  let captured
  globalThis.fetch = async (url, init) => {
    captured = { url: String(url), init }
    return new Response(JSON.stringify({ products_link_url: "https://instacart/link/abc" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  const appBody = {
    provider: "instacart",
    title: "Dutch Oven Chili",
    line_items: [
      { name: "ground beef", quantity: 1, unit: "lb", display_text: "1 lb ground beef" },
      { name: "onion", quantity: 2 },
    ],
    landing_page_configuration: { partner_linkback_url: "https://dutchovendaddy.com/recipe/chili" },
  }
  const resp = await worker.fetch(makeRequest(appBody), baseEnv())
  assert.equal(resp.status, 200)
  assert.deepEqual(await resp.json(), { products_link_url: "https://instacart/link/abc" })

  // Hit the sandbox host + the IDP products_link path.
  assert.equal(captured.url, "https://connect.dev.instacart.tools/idp/v1/products/products_link")
  assert.equal(captured.init.headers.Authorization, `Bearer ${INSTACART_KEY}`)
  assert.equal(captured.init.headers["Content-Type"], "application/json")

  const sent = JSON.parse(captured.init.body)
  assert.equal(sent.title, "Dutch Oven Chili")
  assert.equal(sent.link_type, "shopping_list")
  assert.deepEqual(sent.landing_page_configuration, {
    partner_linkback_url: "https://dutchovendaddy.com/recipe/chili",
  })
  // line_items pass through with identical field names.
  assert.deepEqual(sent.line_items, [
    { name: "ground beef", quantity: 1, unit: "lb", display_text: "1 lb ground beef" },
    { name: "onion", quantity: 2 },
  ])
})

test("instacart: defaults to prod host when INSTACART_BASE_URL unset", async () => {
  let capturedUrl
  globalThis.fetch = async (url) => {
    capturedUrl = String(url)
    return new Response(JSON.stringify({ products_link_url: "https://instacart/link/xyz" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }
  const env = baseEnv()
  delete env.INSTACART_BASE_URL
  const resp = await worker.fetch(
    makeRequest({ provider: "instacart", title: "x", line_items: [{ name: "onion" }] }),
    env
  )
  assert.equal(resp.status, 200)
  assert.equal(capturedUrl, "https://connect.instacart.com/idp/v1/products/products_link")
})

test("instacart: upstream error is surfaced as a safe 502 (no key leak)", async () => {
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ error: "bad key" }), { status: 401 })
  const resp = await worker.fetch(
    makeRequest({ provider: "instacart", title: "x", line_items: [{ name: "onion" }] }),
    baseEnv()
  )
  assert.equal(resp.status, 502)
  const payload = await resp.json()
  assert.equal(payload.error, "provider_error")
  assert.equal(payload.provider, "instacart")
  // The response must not echo our API key anywhere.
  assert.ok(!JSON.stringify(payload).includes(INSTACART_KEY))
})

// MARK: - walmart_plus fallback

test("walmart_plus: builds a search URL from ingredient names (no vendor key)", async () => {
  let called = false
  globalThis.fetch = async () => {
    called = true
    return new Response("{}")
  }
  const resp = await worker.fetch(
    makeRequest({
      provider: "walmart_plus",
      title: "Chili",
      line_items: [{ name: "ground beef" }, { name: "onion" }],
    }),
    { DOD_APP_KEY: APP_KEY } // zero Walmart/Instacart credentials
  )
  assert.equal(resp.status, 200)
  const { products_link_url } = await resp.json()
  const u = new URL(products_link_url)
  assert.equal(u.origin + u.pathname, "https://www.walmart.com/search")
  assert.equal(u.searchParams.get("q"), "ground beef, onion")
  assert.equal(u.searchParams.get("affiliateId"), null, "no affiliate param when unset")
  assert.equal(called, false, "fallback makes no upstream call")
})

test("walmart_plus: appends affiliateId when WALMART_AFFILIATE_ID is set", async () => {
  const resp = await worker.fetch(
    makeRequest({ provider: "walmart_plus", title: "Chili", line_items: [{ name: "onion" }] }),
    { DOD_APP_KEY: APP_KEY, WALMART_AFFILIATE_ID: "aff-123" }
  )
  assert.equal(resp.status, 200)
  const { products_link_url } = await resp.json()
  assert.equal(new URL(products_link_url).searchParams.get("affiliateId"), "aff-123")
})
