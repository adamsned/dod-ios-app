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

// DUT-678 — reliability. Both upstream calls to Apple had no timeout, so a
// stalled Apple endpoint could hang the request (and the Delete Account UI)
// until the platform killed it. Cap each fetch, and give the compliance-
// critical revoke one idempotent retry on a transient failure.
const APPLE_FETCH_TIMEOUT_MS = 10_000
const REVOKE_RETRY_BACKOFF_MS = 300

// A thrown fetch (network error) or an AbortSignal.timeout() firing both land
// here — the latter as a DOMException named "TimeoutError". `fetchApple`
// normalizes them into this sentinel so callers can map to a clean 504.
class UpstreamTimeoutError extends Error {
  constructor(cause?: unknown) {
    super("upstream_timeout")
    this.name = "UpstreamTimeoutError"
    this.cause = cause
  }
}

const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms))

// POST a form to Apple with a hard timeout. Any abort/timeout/network throw is
// re-thrown as UpstreamTimeoutError (secrets never enter the message).
async function fetchApple(url: string, form: URLSearchParams): Promise<Response> {
  try {
    return await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
      signal: AbortSignal.timeout(APPLE_FETCH_TIMEOUT_MS),
    })
  } catch (err) {
    throw new UpstreamTimeoutError(err)
  }
}

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
      // DUT-678: a stalled/unreachable Apple endpoint surfaces as an
      // UpstreamTimeoutError. Return a clean 504 (not a generic 500) so the
      // caller can distinguish "Apple didn't answer in time" and retry.
      if (err instanceof UpstreamTimeoutError) {
        console.error("siwa-revoke upstream_timeout", err)
        return json({ error: "upstream_timeout" }, 504)
      }
      // Never leak key material / internals to the client. The exception can
      // carry WebCrypto/atob diagnostics over the .p8 (APPLE_PRIVATE_KEY), so
      // log it server-side (visible in `wrangler tail`) and return a generic
      // body only. (DUT-258)
      console.error("siwa-revoke server_error", err)
      return json({ error: "server_error" }, 500)
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
  // Single-shot exchange (the /revoke path below carries the idempotent retry;
  // an authorization_code is one-time so retrying an exchange is not always
  // safe). A timeout throws UpstreamTimeoutError -> 504 in the top-level catch.
  const resp = await fetchApple(APPLE_TOKEN_URL, form)
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

  // DUT-678: /auth/revoke is idempotent on Apple's side (revoking an already-
  // revoked or unknown token is a no-op), so on a TRANSIENT failure — an Apple
  // 5xx OR a fetch throw/timeout — retry ONCE after a short backoff. A 4xx is a
  // permanent client error (bad token / bad secret); never retry that. This is
  // the compliance-critical path (App Store 5.1.1(v)).
  let resp: Response
  try {
    resp = await fetchApple(APPLE_REVOKE_URL, form)
  } catch (err) {
    // First attempt timed out / threw — treat as transient and retry once.
    if (err instanceof UpstreamTimeoutError) {
      await sleep(REVOKE_RETRY_BACKOFF_MS)
      resp = await fetchApple(APPLE_REVOKE_URL, form) // a throw here -> 504 (top-level catch)
    } else {
      throw err
    }
  }

  // Retry once on an Apple 5xx (transient). Leave 4xx alone (permanent).
  if (resp.status >= 500) {
    await sleep(REVOKE_RETRY_BACKOFF_MS)
    resp = await fetchApple(APPLE_REVOKE_URL, form) // a throw here -> 504 (top-level catch)
  }

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
