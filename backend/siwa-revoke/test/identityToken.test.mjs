// Guards the Sign in with Apple identityToken verifier (DUT-861 / DUT-2400): only a
// signature-valid, unexpired token for our audience from Apple yields a `sub`.
//   node --test backend/siwa-revoke/test/identityToken.test.mjs
//
// Like the sibling tests, this replicates the code in src/ownerSession.ts verbatim.
import assert from "node:assert/strict"
import { test } from "node:test"

// --- verbatim copy of src/ownerSession.ts (types stripped) ----------------
const APPLE_ISSUER = "https://appleid.apple.com"

function b64urlToBytes(s) {
  const pad = "=".repeat((4 - (s.length % 4)) % 4)
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad)
  return Uint8Array.from(bin, (c) => c.charCodeAt(0))
}

async function verifyAppleIdentityToken(token, jwks, audience, nowSeconds) {
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const dec = new TextDecoder()
    const header = JSON.parse(dec.decode(b64urlToBytes(parts[0])))
    if (header.alg !== "RS256") return null
    const jwk = jwks.find((k) => k.kid === header.kid)
    if (!jwk) return null
    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    )
    const ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      b64urlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
    )
    if (!ok) return null
    const payload = JSON.parse(dec.decode(b64urlToBytes(parts[1])))
    if (payload.iss !== APPLE_ISSUER) return null
    if (payload.aud !== audience) return null
    if (typeof payload.exp !== "number" || payload.exp <= nowSeconds) return null
    if (typeof payload.sub !== "string" || payload.sub.length === 0) return null
    return payload.sub
  } catch {
    return null
  }
}
// -------------------------------------------------------------------------

const AUD = "com.dutchovendaddy.app"
const NOW = 1_800_000_000
const { privateKey, publicKey } = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true,
  ["sign", "verify"]
)
const { n, e } = await crypto.subtle.exportKey("jwk", publicKey)
const jwks = [{ kid: "k1", kty: "RSA", n, e }]

const b64url = (bytes) => Buffer.from(bytes).toString("base64url")
const enc = (obj) => b64url(new TextEncoder().encode(JSON.stringify(obj)))

async function sign(payload, kid = "k1") {
  const signingInput = `${enc({ alg: "RS256", kid })}.${enc(payload)}`
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", privateKey, new TextEncoder().encode(signingInput))
  return `${signingInput}.${b64url(new Uint8Array(sig))}`
}

const good = { iss: APPLE_ISSUER, aud: AUD, exp: NOW + 600, sub: "001234.abc" }

test("a valid token returns its sub", async () => {
  assert.equal(await verifyAppleIdentityToken(await sign(good), jwks, AUD, NOW), "001234.abc")
})

test("an edited payload with the old signature is rejected", async () => {
  const [h, , s] = (await sign(good)).split(".")
  const forged = `${h}.${enc({ ...good, sub: "attacker" })}.${s}`
  assert.equal(await verifyAppleIdentityToken(forged, jwks, AUD, NOW), null)
})

test("a wrong aud is rejected", async () => {
  assert.equal(await verifyAppleIdentityToken(await sign({ ...good, aud: "other" }), jwks, AUD, NOW), null)
})

test("a wrong iss is rejected", async () => {
  assert.equal(await verifyAppleIdentityToken(await sign({ ...good, iss: "https://evil" }), jwks, AUD, NOW), null)
})

test("an expired token is rejected", async () => {
  assert.equal(await verifyAppleIdentityToken(await sign({ ...good, exp: NOW }), jwks, AUD, NOW), null)
})

test("an unknown kid is rejected", async () => {
  assert.equal(await verifyAppleIdentityToken(await sign(good, "k2"), jwks, AUD, NOW), null)
})

test("fewer than three segments is rejected", async () => {
  assert.equal(await verifyAppleIdentityToken("a.b", jwks, AUD, NOW), null)
})
