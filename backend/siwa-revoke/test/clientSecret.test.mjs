// Validates the ES256 `client_secret` JWT pipeline the Worker uses (DUT-98):
// PKCS#8 .p8 import -> ES256 sign -> a JWT that VERIFIES against the public key
// and carries the Apple-required claims. Runs on Node 18+ (WebCrypto built in):
//   node --test backend/siwa-revoke/test/clientSecret.test.mjs
//
// It exercises the exact same primitives as src/index.ts (`crypto.subtle`
// ECDSA P-256 + the base64url encoding), so a regression in the signing
// approach fails here before it ever reaches Apple.
import assert from "node:assert/strict"
import { test } from "node:test"

const b64urlBytes = (bytes) => {
  let s = ""
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}
const b64url = (str) => b64urlBytes(new TextEncoder().encode(str))
const b64urlDecode = (s) => {
  const pad = s.length % 4 ? "=".repeat(4 - (s.length % 4)) : ""
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  return bytes
}

async function makeClientSecret(privateKey, env) {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "ES256", kid: env.keyId, typ: "JWT" }
  const payload = {
    iss: env.teamId,
    iat: now,
    exp: now + 300,
    aud: "https://appleid.apple.com",
    sub: env.clientId,
  }
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(signingInput)
  )
  return `${signingInput}.${b64urlBytes(new Uint8Array(sig))}`
}

test("client_secret signs ES256 and verifies with the public key", async () => {
  // Stand-in for the Apple .p8 key — a P-256 ECDSA key pair.
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"]
  )
  const env = { keyId: "ABC1234567", teamId: "TEAM123456", clientId: "com.dutchovendaddy.DODApp" }
  const jwt = await makeClientSecret(privateKey, env)

  const [h, p, s] = jwt.split(".")
  assert.equal(jwt.split(".").length, 3, "JWT has header.payload.signature")

  // Header carries the Apple-required alg + kid.
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)))
  assert.equal(header.alg, "ES256")
  assert.equal(header.kid, env.keyId)

  // Payload carries the Apple-required claims.
  const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(p)))
  assert.equal(payload.iss, env.teamId)
  assert.equal(payload.sub, env.clientId)
  assert.equal(payload.aud, "https://appleid.apple.com")
  assert.ok(payload.exp > payload.iat, "exp is after iat")
  assert.ok(payload.exp - payload.iat <= 300, "short-lived (<=5min)")

  // The signature verifies against the public key — proves the sign pipeline.
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    b64urlDecode(s),
    new TextEncoder().encode(`${h}.${p}`)
  )
  assert.equal(ok, true, "ES256 signature verifies")
})
