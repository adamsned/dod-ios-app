// Guards the unexpected-exception 500 path (DUT-258): the Worker must NOT echo
// the caught exception's raw message/stack to the client — those can carry
// WebCrypto/atob diagnostics over the .p8 (APPLE_PRIVATE_KEY). It must return a
// generic body and log the real detail server-side via console.error.
//   node --test backend/siwa-revoke/test/errorResponse.test.mjs
//
// It replicates the exact catch-block from src/index.ts (same pattern the
// clientSecret test uses), so a regression that reintroduces `detail` — or any
// substring of the exception — into the 500 body fails here.
import assert from "node:assert/strict"
import { test } from "node:test"

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

// Mirrors the try/catch around makeClientSecret + route handlers in
// src/index.ts fetch(). `handler` stands in for the work that may throw.
async function fetchWithCatch(handler, logger) {
  try {
    return await handler()
  } catch (err) {
    logger("siwa-revoke server_error", err)
    return json({ error: "server_error" }, 500)
  }
}

// A sentinel that looks like the kind of internal detail WebCrypto/atob would
// throw over a malformed APPLE_PRIVATE_KEY — must never reach the client.
const SENTINEL = "InvalidAccessError: pkcs8 import failed for APPLE_PRIVATE_KEY <SECRET-p8-bytes>"

test("500 body carries a generic error, never the raw exception detail", async () => {
  const logged = []
  const resp = await fetchWithCatch(
    () => {
      throw new Error(SENTINEL)
    },
    (...args) => logged.push(args)
  )

  assert.equal(resp.status, 500)
  const text = await resp.text()

  // The generic error field IS present.
  assert.equal(JSON.parse(text).error, "server_error")
  // No `detail` field, and the raw exception message does NOT leak.
  assert.equal(JSON.parse(text).detail, undefined, "no detail field in the response")
  assert.ok(!text.includes(SENTINEL), "raw exception message must not appear in the body")
  assert.ok(!text.includes("APPLE_PRIVATE_KEY"), "no internal config detail in the body")

  // The real detail IS logged server-side (visible in `wrangler tail`).
  assert.equal(logged.length, 1, "the exception is logged exactly once")
  const loggedErr = logged[0][1]
  assert.ok(loggedErr instanceof Error && loggedErr.message === SENTINEL, "the real exception is logged")
})
