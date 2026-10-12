import { describe, expect, it } from "vitest"
import worker, { type Env } from "../src/index"
import { listDevices, validateRegistration } from "../src/devices"
import { fakeKV, TOKEN_A, TOKEN_B } from "./helpers"

const good = { token: TOKEN_A, environment: "production", bundleId: "com.dutchovendaddy.DODApp", appVersion: "1.2.3", newRecipes: true, newArticles: false }

function makeEnv() {
  return { DEVICES: fakeKV(), APP_SHARED_SECRET: "s3cret", APNS_KEY_ID: "K", APNS_TEAM_ID: "T", APNS_TOPIC: "x", APNS_PRIVATE_KEY: "" } as unknown as Env & { DEVICES: ReturnType<typeof fakeKV> }
}
const req = (env: Env, method: string, path: string, body?: unknown, secret: string | null = "s3cret") =>
  worker.fetch(
    new Request(`https://w.example${path}`, {
      method,
      headers: secret === null ? {} : { "X-App-Secret": secret },
      body: body === undefined || method === "GET" ? undefined : JSON.stringify(body),
    }),
    env
  )

describe("auth", () => {
  it("rejects missing, wrong and near-miss secrets on every route", async () => {
    const env = makeEnv()
    for (const [m, p] of [["POST", "/register"], ["DELETE", "/register"], ["POST", "/test"], ["GET", "/health"]]) {
      expect((await req(env, m, p, good, null)).status).toBe(401)
      expect((await req(env, m, p, good, "wrong")).status).toBe(401)
      expect((await req(env, m, p, good, "s3cre")).status).toBe(401)
    }
  })
  it("an empty configured secret never authorizes", async () => {
    const env = makeEnv()
    env.APP_SHARED_SECRET = ""
    expect((await req(env, "GET", "/health", undefined, "")).status).toBe(401)
  })
  it("unknown path is 404", async () => {
    expect((await req(makeEnv(), "GET", "/nope")).status).toBe(404)
  })
})

describe("registration validation", () => {
  it("accepts a good body and lowercases the token", () => {
    const r = validateRegistration({ ...good, token: "A".repeat(64) })
    expect(r.ok && r.value.token).toBe("a".repeat(64))
  })
  it.each([
    ["short token", { token: "ab".repeat(31) }, "invalid_token"],
    ["long token", { token: "a".repeat(201) }, "invalid_token"],
    ["non-hex token", { token: "z".repeat(64) }, "invalid_token"],
    ["numeric token", { token: 5 }, "invalid_token"],
    ["bad environment", { environment: "staging" }, "invalid_environment"],
    ["bad bundle", { bundleId: "no spaces/allowed" }, "invalid_bundle_id"],
    ["bad version", { appVersion: "" }, "invalid_app_version"],
    ["string flag", { newRecipes: "true" }, "invalid_new_recipes"],
    ["missing flag", { newArticles: undefined }, "invalid_new_articles"],
  ])("rejects %s", (_n, patch, error) => {
    expect(validateRegistration({ ...good, ...patch })).toEqual({ ok: false, error })
  })
  it("rejects non-objects", () => {
    for (const b of [null, [], "x", 3]) expect(validateRegistration(b)).toEqual({ ok: false, error: "invalid_body" })
  })
  it("200-char token is accepted", () => {
    expect(validateRegistration({ ...good, token: "f".repeat(200) }).ok).toBe(true)
  })
})

describe("KV store / delete / health", () => {
  it("stores by token, is idempotent, updates flags, deletes", async () => {
    const env = makeEnv()
    expect((await req(env, "POST", "/register", good)).status).toBe(200)
    expect((await req(env, "POST", "/register", good)).status).toBe(200)
    expect(env.DEVICES.data.size).toBe(1)
    const stored = JSON.parse(env.DEVICES.data.get(`device:${TOKEN_A}`)!.value)
    expect(stored).toMatchObject({ environment: "production", newRecipes: true, newArticles: false })
    expect(typeof stored.updatedAt).toBe("number")

    await req(env, "POST", "/register", { ...good, newArticles: true })
    expect((await listDevices(env.DEVICES))[0]).toMatchObject({ token: TOKEN_A, newRecipes: true, newArticles: true })

    expect((await req(env, "DELETE", "/register", { token: TOKEN_A })).status).toBe(200)
    expect(env.DEVICES.data.size).toBe(0)
    expect((await req(env, "DELETE", "/register", { token: "bad" })).status).toBe(400)
  })
  it("invalid body returns 400 and stores nothing", async () => {
    const env = makeEnv()
    expect((await req(env, "POST", "/register", { ...good, environment: "x" })).status).toBe(400)
    expect(env.DEVICES.data.size).toBe(0)
  })
  it("health returns counts only, across KV pages", async () => {
    const env = makeEnv()
    await req(env, "POST", "/register", good)
    await req(env, "POST", "/register", { ...good, token: TOKEN_B, environment: "development" })
    await req(env, "POST", "/register", { ...good, token: "c".repeat(64), environment: "development" })
    const body = await (await req(env, "GET", "/health")).json()
    expect(body).toEqual({ devices: { production: 1, development: 2, total: 3 } })
  })
})

describe("/test", () => {
  it("validates the token and surfaces APNs status and reason", async () => {
    const env = makeEnv()
    expect((await req(env, "POST", "/test", { token: "bad" })).status).toBe(400)
    expect((await req(env, "POST", "/test", { token: TOKEN_A, environment: "nope" })).status).toBe(400)
    // Unusable key: the failure is reported as JSON status 0, never thrown to the caller.
    const r = await req(env, "POST", "/test", { token: TOKEN_A, environment: "development" })
    expect(r.status).toBe(200)
    expect(await r.json()).toEqual({ status: 0, reason: "NetworkError" })
  })
})
