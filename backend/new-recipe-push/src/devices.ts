// Device registry in Workers KV. Key: device:<token>. The value carries the
// fields; the same fields are mirrored into KV metadata so a single list()
// call yields every device without one get() per token.
export type ApnsEnvironment = "production" | "development"

export interface Device {
  token: string
  environment: ApnsEnvironment
  newRecipes: boolean
  newArticles: boolean
}

export interface Registration extends Device {
  bundleId: string
  appVersion: string
}

export const DEVICE_PREFIX = "device:"

type Result<T> = { ok: true; value: T } | { ok: false; error: string }

const TOKEN_RE = /^[0-9a-fA-F]{64,200}$/
const BUNDLE_RE = /^[A-Za-z0-9.-]{1,155}$/
const VERSION_RE = /^[A-Za-z0-9.+-]{1,40}$/

export function validateToken(raw: unknown): Result<string> {
  if (typeof raw !== "string" || !TOKEN_RE.test(raw)) return { ok: false, error: "invalid_token" }
  return { ok: true, value: raw.toLowerCase() }
}

export function validateRegistration(body: unknown): Result<Registration> {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return { ok: false, error: "invalid_body" }
  }
  const b = body as Record<string, unknown>
  const token = validateToken(b.token)
  if (!token.ok) return token
  if (b.environment !== "production" && b.environment !== "development") {
    return { ok: false, error: "invalid_environment" }
  }
  if (typeof b.bundleId !== "string" || !BUNDLE_RE.test(b.bundleId)) {
    return { ok: false, error: "invalid_bundle_id" }
  }
  if (typeof b.appVersion !== "string" || !VERSION_RE.test(b.appVersion)) {
    return { ok: false, error: "invalid_app_version" }
  }
  if (typeof b.newRecipes !== "boolean") return { ok: false, error: "invalid_new_recipes" }
  if (typeof b.newArticles !== "boolean") return { ok: false, error: "invalid_new_articles" }
  return {
    ok: true,
    value: {
      token: token.value,
      environment: b.environment,
      bundleId: b.bundleId,
      appVersion: b.appVersion,
      newRecipes: b.newRecipes,
      newArticles: b.newArticles,
    },
  }
}

// Idempotent: a repeat registration just overwrites the same key.
export async function saveDevice(kv: KVNamespace, reg: Registration, now: number): Promise<void> {
  const fields = { environment: reg.environment, newRecipes: reg.newRecipes, newArticles: reg.newArticles }
  await kv.put(DEVICE_PREFIX + reg.token, JSON.stringify({ ...fields, updatedAt: now }), { metadata: fields })
}

export async function deleteDevice(kv: KVNamespace, token: string): Promise<void> {
  await kv.delete(DEVICE_PREFIX + token)
}

export async function listDevices(kv: KVNamespace): Promise<Device[]> {
  const out: Device[] = []
  let cursor: string | undefined
  do {
    const page = await kv.list<Partial<Device>>({ prefix: DEVICE_PREFIX, cursor })
    for (const k of page.keys) {
      const m = k.metadata
      if (!m || (m.environment !== "production" && m.environment !== "development")) continue
      out.push({
        token: k.name.slice(DEVICE_PREFIX.length),
        environment: m.environment,
        newRecipes: m.newRecipes === true,
        newArticles: m.newArticles === true,
      })
    }
    cursor = page.list_complete ? undefined : (page as { cursor?: string }).cursor
  } while (cursor)
  return out
}
