import { beforeEach, describe, expect, it, vi } from "vitest"
import { getApnsJwt, JWT_TTL_SECONDS, makeJwt, mapLimit, resetJwtCache, sendPush } from "../src/apns"
import { fakeSendDeps, throwawayPem, TOKEN_A } from "./helpers"

const dec = (s: string) => {
  const pad = s.length % 4 ? "=".repeat(4 - (s.length % 4)) : ""
  return Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad), (c) => c.charCodeAt(0))
}

describe("JWT", () => {
  beforeEach(resetJwtCache)
  it("has ES256 header, iss/iat claims and a signature that verifies", async () => {
    const { pem, publicKey } = await throwawayPem()
    const jwt = await makeJwt({ APNS_KEY_ID: "ABC1234567", APNS_TEAM_ID: "TEAM123456", APNS_TOPIC: "t", APNS_PRIVATE_KEY: pem }, 1_700_000_000)
    const [h, p, s] = jwt.split(".")
    expect(JSON.parse(new TextDecoder().decode(dec(h)))).toEqual({ alg: "ES256", kid: "ABC1234567", typ: "JWT" })
    expect(JSON.parse(new TextDecoder().decode(dec(p)))).toEqual({ iss: "TEAM123456", iat: 1_700_000_000 })
    expect(dec(s).length).toBe(64)
    expect(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, dec(s), new TextEncoder().encode(`${h}.${p}`))).toBe(true)
  })
  it("is cached for 50 minutes then refreshed", async () => {
    const { pem } = await throwawayPem()
    const env = { APNS_KEY_ID: "K", APNS_TEAM_ID: "T", APNS_TOPIC: "t", APNS_PRIVATE_KEY: pem }
    const a = await getApnsJwt(env, 1000)
    expect(await getApnsJwt(env, 1000 + JWT_TTL_SECONDS - 1)).toBe(a)
    expect(await getApnsJwt(env, 1000 + JWT_TTL_SECONDS)).not.toBe(a)
    expect(JWT_TTL_SECONDS).toBe(3000)
  })
})

describe("sendPush", () => {
  const dev = { token: TOKEN_A, environment: "production" as const }
  const payload = { aps: { alert: { title: "t", body: "b" } } }
  beforeEach(() => vi.spyOn(console, "warn").mockImplementation(() => {}))

  it("200 is ok and sends the required headers to the production host", async () => {
    const { deps, calls } = fakeSendDeps()
    expect((await sendPush(deps, dev, payload, "post-1")).outcome).toBe("ok")
    expect(calls[0].url).toBe(`https://api.push.apple.com/3/device/${TOKEN_A}`)
    expect(calls[0].headers).toMatchObject({
      authorization: "bearer test.jwt.value",
      "apns-topic": "com.dutchovendaddy.DODApp",
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(1_700_000_000 + 86400),
      "apns-collapse-id": "post-1",
    })
    expect(JSON.parse(calls[0].body)).toEqual(payload)
  })
  it("development tokens use the sandbox host", async () => {
    const { deps, calls } = fakeSendDeps()
    await sendPush(deps, { ...dev, environment: "development" }, payload)
    expect(calls[0].url.startsWith("https://api.sandbox.push.apple.com/3/device/")).toBe(true)
  })
  it("410, BadDeviceToken and Unregistered mean dead token, no retry", async () => {
    for (const s of [[410, "Unregistered"], [400, "BadDeviceToken"], [400, "Unregistered"]] as Array<[number, string]>) {
      const { deps, calls } = fakeSendDeps({ [TOKEN_A]: [s] })
      expect((await sendPush(deps, dev, payload)).outcome).toBe("dead")
      expect(calls.length).toBe(1)
    }
  })
  it("429/5xx retries once; success on retry is ok", async () => {
    const { deps, calls } = fakeSendDeps({ [TOKEN_A]: [[503, "ServiceUnavailable"], 200] })
    expect((await sendPush(deps, dev, payload)).outcome).toBe("ok")
    expect(calls.length).toBe(2)
  })
  it("persistent 429 retries once then is left for later", async () => {
    const { deps, calls } = fakeSendDeps({ [TOKEN_A]: [[429, "TooManyRequests"]] })
    expect(await sendPush(deps, dev, payload)).toEqual({ status: 429, reason: "TooManyRequests", outcome: "retry_later" })
    expect(calls.length).toBe(2)
  })
  it("a network error is retried once and reported quietly", async () => {
    const { deps } = fakeSendDeps()
    let n = 0
    deps.fetch = (async () => { n++; throw new Error("boom") }) as unknown as typeof fetch
    expect((await sendPush(deps, dev, payload)).outcome).toBe("retry_later")
    expect(n).toBe(2)
  })
  it("other 4xx is a plain error, not retried, token kept", async () => {
    const { deps, calls } = fakeSendDeps({ [TOKEN_A]: [[400, "PayloadEmpty"]] })
    expect((await sendPush(deps, dev, payload)).outcome).toBe("error")
    expect(calls.length).toBe(1)
  })
  it("logs status and reason but never the full token", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    const { deps } = fakeSendDeps({ [TOKEN_A]: [[400, "PayloadEmpty"]] })
    await sendPush(deps, dev, payload)
    const line = String(warn.mock.calls.at(-1)![0])
    expect(line).toContain("status=400")
    expect(line).toContain("PayloadEmpty")
    expect(line).not.toContain(TOKEN_A)
  })
})

describe("mapLimit", () => {
  it("never exceeds the concurrency limit and keeps order", async () => {
    let active = 0, peak = 0
    const out = await mapLimit([1, 2, 3, 4, 5, 6, 7], 3, async (n) => {
      peak = Math.max(peak, ++active)
      await new Promise((r) => setTimeout(r, 5))
      active--
      return n * 2
    })
    expect(out).toEqual([2, 4, 6, 8, 10, 12, 14])
    expect(peak).toBe(3)
  })
})
