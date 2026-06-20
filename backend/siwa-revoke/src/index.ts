// Dutch Oven Daddy — Sign in with Apple revoke Worker (DUT-98 / T-797).
//
// A tiny STATELESS Cloudflare Worker that lets the iOS app satisfy App Store
// Review Guideline 5.1.1(v): account deletion must REVOKE the Sign in with
// Apple token. There is no pure-client way to do this — Apple's /auth/token
// and /auth/revoke require a server-signed `client_secret` (an ES256 JWT
// signed with your Sign in with Apple private key). This Worker holds that key
// (as an encrypted secret) and exposes exactly two operations:
//
//   POST /exchange  { "code": "<authorizationCode>" }     -> { "refreshToken": "..." }
//       Called once at sign-in. Exchanges the one-time authorization code the
//       app got from ASAuthorizationAppleIDCredential for a long-lived refresh
//       token, which the app stores in its Keychain session.
//
//   POST /revoke    { "refreshToken": "<refreshToken>" }  -> { "revoked": true }
//       Called when the user taps Delete Account. Revokes the token so the app
//       disappears from Settings -> Apple ID -> Sign in with Apple.
//
// Stateless by design: the Worker stores nothing; the app holds the refresh
// token. That keeps DUT-98 to a single deployable file with no database. (A
// future DUT-16 Phase d cross-device-sync backend can supersede it.)
//
// Every request must carry `X-DOD-App-Key: <APP_SHARED_SECRET>` — the same
// shared-secret gate the WordPress comment endpoint uses — so the endpoint
// isn't an open relay. Native apps don't trigger CORS, so none is sent.

export interface Env {
  APPLE_KEY_ID: string // the Sign in with Apple Key ID (10 chars)
  APPLE_TEAM_ID: string // Apple Developer Team ID (10 chars)
  APPLE_CLIENT_ID: string // the app's bundle id, e.g. com.dutchovendaddy.DODApp
  APPLE_PRIVATE_KEY: string // the .p8 contents (PKCS#8 PEM), set via `wrangler secret put`
  APP_SHARED_SECRET: string // shared gate; the app sends it as X-DOD-App-Key
}

const APPLE_AUDIENCE = "https://appleid.apple.com"
const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke"

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405)
    }
    if (request.headers.get("X-DOD-App-Key") !== env.APP_SHARED_SECRET) {
      return json({ error: "unauthorized" }, 401)
    }

    const url = new URL(request.url)
    try {
      const clientSecret = await makeClientSecret(env)
      if (url.pathname === "/exchange") {
        return await handleExchange(request, env, clientSecret)
      }
      if (url.pathname === "/revoke") {
        return await handleRevoke(request, env, clientSecret)
      }
      return json({ error: "not_found" }, 404)
    } catch (err) {
      // Never leak key material / internals to the client.
      return json({ error: "server_error", detail: String((err as Error).message) }, 500)
    }
  },
}

async function handleExchange(request: Request, env: Env, clientSecret: string): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as { code?: string }
  if (!body.code) return json({ error: "missing_code" }, 400)

  const form = new URLSearchParams({
    client_id: env.APPLE_CLIENT_ID,
    client_secret: clientSecret,
    code: body.code,
    grant_type: "authorization_code",
  })
  const resp = await fetch(APPLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  })
  const data = (await resp.json().catch(() => ({}))) as { refresh_token?: string; error?: string }
  if (!resp.ok || !data.refresh_token) {
    return json({ error: "exchange_failed", apple: data.error ?? null }, 502)
  }
  return json({ refreshToken: data.refresh_token })
}

async function handleRevoke(request: Request, env: Env, clientSecret: string): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as { refreshToken?: string }
  if (!body.refreshToken) return json({ error: "missing_refresh_token" }, 400)

  const form = new URLSearchParams({
    client_id: env.APPLE_CLIENT_ID,
    client_secret: clientSecret,
    token: body.refreshToken,
    token_type_hint: "refresh_token",
  })
  const resp = await fetch(APPLE_REVOKE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  })
  // Apple returns 200 with an empty body on success. Treat 200 as revoked;
  // surface the status otherwise so the app can decide whether to retry.
  if (!resp.ok) {
    return json({ revoked: false, appleStatus: resp.status }, 502)
  }
  return json({ revoked: true })
}

// MARK: - client_secret (ES256 JWT signed with the Apple .p8 key)

async function makeClientSecret(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "ES256", kid: env.APPLE_KEY_ID, typ: "JWT" }
  const payload = {
    iss: env.APPLE_TEAM_ID,
    iat: now,
    exp: now + 300, // 5 min — short-lived; minted per request.
    aud: APPLE_AUDIENCE,
    sub: env.APPLE_CLIENT_ID,
  }
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`
  const key = await importPrivateKey(env.APPLE_PRIVATE_KEY)
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  )
  return `${signingInput}.${b64urlBytes(new Uint8Array(signature))}`
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // The .p8 is a PKCS#8 PEM. Strip the header/footer + whitespace, base64-decode
  // to DER, import as an ECDSA P-256 signing key.
  const der = pemToDer(pem)
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "")
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

// MARK: - helpers

function b64url(input: string): string {
  return b64urlBytes(new TextEncoder().encode(input))
}

function b64urlBytes(bytes: Uint8Array): string {
  let binary = ""
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
