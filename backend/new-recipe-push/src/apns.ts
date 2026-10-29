// APNs HTTP/2 sender via fetch + ES256 provider token signed with WebCrypto.
import type { ApnsEnvironment } from "./devices"

export interface ApnsEnv {
  APNS_KEY_ID: string
  APNS_TEAM_ID: string
  APNS_TOPIC: string
  APNS_PRIVATE_KEY: string
}

export const JWT_TTL_SECONDS = 50 * 60 // Apple: refresh at most hourly, reject > 1h old
const HOSTS: Record<ApnsEnvironment, string> = {
  production: "https://api.push.apple.com",
  development: "https://api.sandbox.push.apple.com",
}
const DEAD_REASONS = new Set(["BadDeviceToken", "Unregistered"])
const FETCH_TIMEOUT_MS = 10_000
const RETRY_BACKOFF_MS = 500
const EXPIRATION_SECONDS = 24 * 60 * 60

// MARK: JWT

let cache: { key: string; jwt: string; iat: number } | null = null
export function resetJwtCache(): void {
  cache = null
}

export async function getApnsJwt(env: ApnsEnv, nowSeconds: number): Promise<string> {
  const key = `${env.APNS_TEAM_ID}:${env.APNS_KEY_ID}`
  if (cache && cache.key === key && nowSeconds - cache.iat < JWT_TTL_SECONDS) return cache.jwt
  const jwt = await makeJwt(env, nowSeconds)
  cache = { key, jwt, iat: nowSeconds }
  return jwt
}

export async function makeJwt(env: ApnsEnv, iat: number): Promise<string> {
  const header = { alg: "ES256", kid: env.APNS_KEY_ID, typ: "JWT" }
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify({ iss: env.APNS_TEAM_ID, iat }))}`
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(env.APNS_PRIVATE_KEY),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput))
  return `${signingInput}.${b64urlBytes(new Uint8Array(sig))}`
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----(BEGIN|END) [^-]+-----/g, "").replace(/\s+/g, "")
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

const b64url = (s: string) => b64urlBytes(new TextEncoder().encode(s))
function b64urlBytes(bytes: Uint8Array): string {
  let bin = ""
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

// MARK: send

export type Outcome = "ok" | "dead" | "retry_later" | "error"
export interface SendResult {
  status: number // 0 = network failure
  reason?: string
  outcome: Outcome
}

export interface SendDeps {
  fetch: typeof fetch
  jwt: () => Promise<string>
  topic: string
  now: () => number // ms
  sleep: (ms: number) => Promise<void>
  dropJwt?: () => void
}

const redact = (token: string) => `${token.slice(0, 6)}...${token.slice(-4)}`

async function attempt(deps: SendDeps, token: string, environment: ApnsEnvironment, body: string, collapseId?: string): Promise<{ status: number; reason?: string }> {
  try {
    const headers: Record<string, string> = {
      authorization: `bearer ${await deps.jwt()}`,
      "apns-topic": deps.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(deps.now() / 1000) + EXPIRATION_SECONDS),
      "content-type": "application/json",
    }
    if (collapseId) headers["apns-collapse-id"] = collapseId
    const resp = await deps.fetch(`${HOSTS[environment]}/3/device/${token}`, {
      method: "POST",
      headers,
      body,
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    })
    if (resp.status === 200) return { status: 200 }
    const data = (await resp.json().catch(() => ({}))) as { reason?: unknown }
    return { status: resp.status, reason: typeof data.reason === "string" ? data.reason : undefined }
  } catch {
    return { status: 0, reason: "NetworkError" }
  }
}

const transient = (status: number) => status === 0 || status === 429 || status >= 500

export async function sendPush(
  deps: SendDeps,
  device: { token: string; environment: ApnsEnvironment },
  payload: unknown,
  collapseId?: string
): Promise<SendResult> {
  const body = JSON.stringify(payload)
  let r = await attempt(deps, device.token, device.environment, body, collapseId)
  if (transient(r.status)) {
    await deps.sleep(RETRY_BACKOFF_MS)
    r = await attempt(deps, device.token, device.environment, body, collapseId)
  }
  let outcome: Outcome
  if (r.status === 200) outcome = "ok"
  else if (r.status === 410 || (r.reason && DEAD_REASONS.has(r.reason))) outcome = "dead"
  else if (transient(r.status)) outcome = "retry_later"
  else outcome = "error"
  if (outcome !== "ok") {
    if (r.status === 403) deps.dropJwt?.() // ExpiredProviderToken etc.: mint a fresh one next time
    console.warn(`apns_failure status=${r.status} reason=${r.reason ?? "none"} outcome=${outcome} env=${device.environment} token=${redact(device.token)}`)
  }
  return { status: r.status, reason: r.reason, outcome }
}

// Run `fn` over items with at most `limit` in flight.
export async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length)
  let next = 0
  const worker = async () => {
    while (next < items.length) {
      const i = next++
      out[i] = await fn(items[i])
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker))
  return out
}

export function makeDeps(env: ApnsEnv): SendDeps {
  return {
    fetch: (...a) => fetch(...a),
    jwt: () => getApnsJwt(env, Math.floor(Date.now() / 1000)),
    topic: env.APNS_TOPIC,
    now: () => Date.now(),
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
    dropJwt: resetJwtCache,
  }
}
