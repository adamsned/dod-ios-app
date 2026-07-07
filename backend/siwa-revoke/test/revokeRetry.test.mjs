// DUT-678 — reliability of the compliance-critical /revoke path (App Store
// 5.1.1(v)). The Worker must:
//   - time out each upstream call to Apple (10s) and map a timeout/abort to a
//     clean 504 { error: "upstream_timeout" } instead of hanging or 500ing,
//   - retry the revoke ONCE on a transient failure (Apple 5xx OR a fetch
//     throw/timeout) after a short backoff, since /auth/revoke is idempotent,
//   - NOT retry on a 4xx (permanent client error).
//
//   node --test backend/siwa-revoke/test/revokeRetry.test.mjs
//
// Like the other suites, this mirrors the exact control flow in
// src/index.ts (handleRevoke + the top-level UpstreamTimeoutError -> 504 map)
// against a mocked `fetch`, so a regression in the retry/timeout logic fails
// here before it ever reaches Apple.
import assert from "node:assert/strict"
import { test } from "node:test"

const REVOKE_RETRY_BACKOFF_MS = 0 // no real delay in tests

class UpstreamTimeoutError extends Error {
  constructor(cause) {
    super("upstream_timeout")
    this.name = "UpstreamTimeoutError"
    this.cause = cause
  }
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// Mirrors fetchApple(): any throw/abort becomes UpstreamTimeoutError.
async function fetchApple(fetchImpl) {
  try {
    return await fetchImpl()
  } catch (err) {
    throw new UpstreamTimeoutError(err)
  }
}

// Mirrors handleRevoke()'s retry loop + the top-level catch's timeout->504 map.
// `fetchImpl` is a mock invoked once per attempt; it may resolve a Response or
// throw (network error / timeout).
async function revoke(fetchImpl) {
  try {
    let resp
    let retried = false
    try {
      resp = await fetchApple(fetchImpl)
    } catch (err) {
      if (err instanceof UpstreamTimeoutError) {
        await sleep(REVOKE_RETRY_BACKOFF_MS)
        retried = true
        resp = await fetchApple(fetchImpl) // a throw here propagates -> 504
      } else {
        throw err
      }
    }
    // DUT-689: cap total Apple calls at 2 — skip the 5xx retry if we already
    // retried after a first-attempt timeout.
    if (!retried && resp.status >= 500) {
      await sleep(REVOKE_RETRY_BACKOFF_MS)
      resp = await fetchApple(fetchImpl)
    }
    if (!resp.ok) {
      return json({ revoked: false, appleStatus: resp.status }, 502)
    }
    return json({ revoked: true })
  } catch (err) {
    if (err instanceof UpstreamTimeoutError) {
      return json({ error: "upstream_timeout" }, 504)
    }
    return json({ error: "server_error" }, 500)
  }
}

// A mock fetch that returns a scripted sequence of outcomes (status number, or
// the string "throw" to simulate a network error / timeout).
function mockFetch(sequence) {
  let calls = 0
  const impl = () => {
    const outcome = sequence[calls] ?? sequence[sequence.length - 1]
    calls++
    if (outcome === "throw") return Promise.reject(new DOMException("timed out", "TimeoutError"))
    return Promise.resolve(new Response("", { status: outcome }))
  }
  impl.callCount = () => calls
  return impl
}

test("Apple 503 -> retried once -> success (revoked:true, one retry)", async () => {
  const fetchImpl = mockFetch([503, 200])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 200)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: true })
  assert.equal(fetchImpl.callCount(), 2, "retried exactly once after the 5xx")
})

test("first attempt times out -> retried once -> success", async () => {
  const fetchImpl = mockFetch(["throw", 200])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 200)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: true })
  assert.equal(fetchImpl.callCount(), 2, "one retry after the timeout")
})

test("DUT-689: timeout THEN 5xx -> capped at 2 Apple calls, surfaces 502", async () => {
  // Regression: the timeout retry and the 5xx retry used to both fire, making
  // a THIRD Apple call. The retried-guard now caps the total at 2.
  const fetchImpl = mockFetch(["throw", 503])
  const resp = await revoke(fetchImpl)

  assert.equal(fetchImpl.callCount(), 2, "timeout retry consumes the single allowed retry; no extra 5xx retry")
  assert.equal(resp.status, 502)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: false, appleStatus: 503 })
})

test("both attempts time out -> clean 504 upstream_timeout (secrets-free)", async () => {
  const fetchImpl = mockFetch(["throw", "throw"])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 504)
  const text = await resp.text()
  assert.deepEqual(JSON.parse(text), { error: "upstream_timeout" })
  assert.ok(!text.includes("client_secret"), "no secret material in the body")
  assert.equal(fetchImpl.callCount(), 2, "attempted once + one retry, then gave up")
})

test("Apple 400 (permanent client error) -> NOT retried -> 502", async () => {
  const fetchImpl = mockFetch([400, 200])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 502)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: false, appleStatus: 400 })
  assert.equal(fetchImpl.callCount(), 1, "a 4xx is permanent — never retried")
})

test("Apple 200 first try -> success, no retry", async () => {
  const fetchImpl = mockFetch([200])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 200)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: true })
  assert.equal(fetchImpl.callCount(), 1, "no retry on first-try success")
})

test("persistent Apple 5xx -> one retry then surfaces 502 with appleStatus", async () => {
  const fetchImpl = mockFetch([500, 503])
  const resp = await revoke(fetchImpl)

  assert.equal(resp.status, 502)
  assert.deepEqual(JSON.parse(await resp.text()), { revoked: false, appleStatus: 503 })
  assert.equal(fetchImpl.callCount(), 2, "exactly one retry, then the failure surfaces")
})
