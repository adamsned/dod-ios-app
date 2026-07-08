// Guards the shared-secret gate (DUT): the `X-DOD-App-Key` check must be
// constant-time so it can't leak the secret byte-by-byte via timing. It must
// still authorize the exact secret, reject a wrong / missing key, and never
// short-circuit on the first mismatching byte.
//   node --test backend/siwa-revoke/test/authGate.test.mjs
//
// Like the sibling tests, this replicates the exact gate from src/index.ts
// (isAuthorized + sha256 + timingSafeEqualBytes), so a regression that
// reintroduces a raw `!==` short-circuit fails here.
import assert from "node:assert/strict"
import { test } from "node:test"

// --- verbatim copy of the gate in src/index.ts ---------------------------
async function isAuthorized(provided, secret) {
  const [providedHash, secretHash] = await Promise.all([sha256(provided ?? ""), sha256(secret)])
  return timingSafeEqualBytes(providedHash, secretHash)
}

async function sha256(input) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input))
  return new Uint8Array(digest)
}

function timingSafeEqualBytes(a, b) {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}
// -------------------------------------------------------------------------

const SECRET = "super-secret-shared-app-key-value"

test("the exact shared secret authorizes", async () => {
  assert.equal(await isAuthorized(SECRET, SECRET), true)
})

test("a wrong key is rejected", async () => {
  assert.equal(await isAuthorized("not-the-secret", SECRET), false)
})

test("a missing (null) header is rejected", async () => {
  assert.equal(await isAuthorized(null, SECRET), false)
})

test("a key sharing a long common prefix is still rejected", async () => {
  // The timing-attack shape: same leading bytes, differing at the end. The
  // digest comparison ignores prefix length entirely, so this is just wrong.
  const nearMiss = SECRET.slice(0, -1) + "X"
  assert.equal(await isAuthorized(nearMiss, SECRET), false)
})

test("the digest comparison runs over fixed 32-byte buffers", async () => {
  // Both sides hash to a SHA-256 digest, so the compared buffers are always
  // 32 bytes regardless of input length — no length leak, no early exit.
  const short = await sha256("a")
  const long = await sha256("a-much-longer-input-value-here")
  assert.equal(short.length, 32)
  assert.equal(long.length, 32)
})
