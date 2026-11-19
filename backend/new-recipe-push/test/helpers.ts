import type { SendDeps } from "../src/apns"

// Minimal in-memory KV (get/put/delete/list with metadata, pagination of 2).
export function fakeKV(): KVNamespace & { data: Map<string, { value: string; metadata?: unknown }> } {
  const data = new Map<string, { value: string; metadata?: unknown }>()
  const kv = {
    data,
    async get(k: string) {
      return data.get(k)?.value ?? null
    },
    async put(k: string, value: string, opts?: { metadata?: unknown }) {
      data.set(k, { value, metadata: opts?.metadata })
    },
    async delete(k: string) {
      data.delete(k)
    },
    async list({ prefix = "", cursor }: { prefix?: string; cursor?: string } = {}) {
      const all = [...data.keys()].filter((k) => k.startsWith(prefix)).sort()
      const start = cursor ? Number(cursor) : 0
      const keys = all.slice(start, start + 2).map((name) => ({ name, metadata: data.get(name)!.metadata }))
      const done = start + 2 >= all.length
      return done ? { keys, list_complete: true } : { keys, list_complete: false, cursor: String(start + 2) }
    },
  }
  return kv as unknown as KVNamespace & { data: typeof data }
}

export const TOKEN_A = "a".repeat(64)
export const TOKEN_B = "b".repeat(64)
export const TOKEN_C = "c".repeat(64)

export async function throwawayPem(): Promise<{ pem: string; publicKey: CryptoKey }> {
  const kp = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair
  const der = new Uint8Array((await crypto.subtle.exportKey("pkcs8", kp.privateKey)) as ArrayBuffer)
  let bin = ""
  for (const b of der) bin += String.fromCharCode(b)
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin)}\n-----END PRIVATE KEY-----`
  return { pem, publicKey: kp.publicKey }
}

export interface Call { url: string; headers: Record<string, string>; body: string }

// Fake APNs: status per token (default 200). Records every call.
export function fakeSendDeps(statuses: Record<string, Array<number | [number, string]>> = {}) {
  const calls: Call[] = []
  const counts: Record<string, number> = {}
  const fetchFn = (async (url: string, init: RequestInit) => {
    const token = url.split("/").pop()!
    calls.push({ url, headers: init.headers as Record<string, string>, body: init.body as string })
    const n = (counts[token] = (counts[token] ?? 0) + 1)
    const seq = statuses[token] ?? [200]
    const s = seq[Math.min(n, seq.length) - 1]
    const [status, reason] = Array.isArray(s) ? s : [s, undefined]
    return new Response(status === 200 ? "" : JSON.stringify({ reason }), { status })
  }) as unknown as typeof fetch
  const deps: SendDeps = {
    fetch: fetchFn,
    jwt: async () => "test.jwt.value",
    topic: "com.dutchovendaddy.DODApp",
    now: () => 1_700_000_000_000,
    sleep: async () => {},
  }
  return { deps, calls }
}
