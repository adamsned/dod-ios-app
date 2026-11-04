import { beforeEach, describe, expect, it, vi } from "vitest"
import { runPoll, LAST_SEEN_KEY, MAX_POSTS_PER_RUN } from "../src/poll"
import { saveDevice } from "../src/devices"
import { fakeKV, fakeSendDeps, TOKEN_A, TOKEN_B, TOKEN_C } from "./helpers"

const wp = (id: number, title: string, categories: number[] = [339]) => ({ id, title: { rendered: title }, type: "post", categories })
const site = (posts: unknown[], status = 200) => (async () => new Response(JSON.stringify(posts), { status })) as unknown as typeof fetch

async function setup(statuses = {}) {
  const kv = fakeKV()
  const reg = (token: string, newRecipes: boolean, newArticles: boolean, environment: "production" | "development" = "production") =>
    saveDevice(kv, { token, environment, newRecipes, newArticles, bundleId: "b", appVersion: "1" }, 1)
  await reg(TOKEN_A, true, true)
  await reg(TOKEN_B, true, false, "development")
  await reg(TOKEN_C, false, true)
  const apns = fakeSendDeps(statuses)
  return { kv, apns, run: (posts: unknown[]) => runPoll({ kv, fetchSite: site(posts), send: apns.deps }) }
}
const sentTokens = (calls: { url: string }[]) => calls.map((c) => c.url.split("/").pop()).sort()

beforeEach(() => {
  vi.spyOn(console, "log").mockImplementation(() => {})
  vi.spyOn(console, "warn").mockImplementation(() => {})
})

describe("poll", () => {
  it("first run records a baseline and sends nothing", async () => {
    const { kv, apns, run } = await setup()
    const r = await run([wp(10, "A"), wp(9, "B")])
    expect(r.baseline).toBe(true)
    expect(apns.calls.length).toBe(0)
    expect(await kv.get(LAST_SEEN_KEY)).toBe("10")
  })

  it("sends only new posts, to devices whose flag is on, then advances last-seen", async () => {
    const { kv, apns, run } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    await run([wp(11, "Fish &amp; Chips"), wp(10, "Old")])
    expect(sentTokens(apns.calls)).toEqual([TOKEN_A, TOKEN_B]) // recipe: A and B
    expect(JSON.parse(apns.calls[0].body)).toEqual({
      aps: { alert: { title: "Fish & Chips", body: "A new recipe just dropped" }, sound: "default" },
      postId: 11,
      postKind: "recipe",
    })
    expect(apns.calls.find((c) => c.url.includes(TOKEN_B))!.url).toContain("sandbox")
    expect(await kv.get(LAST_SEEN_KEY)).toBe("11")
  })

  it("articles go only to devices with newArticles on", async () => {
    const { kv, apns, run } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    await run([wp(11, "Guide", [1432, 1590])])
    expect(sentTokens(apns.calls)).toEqual([TOKEN_A, TOKEN_C])
    expect(JSON.parse(apns.calls[0].body).postKind).toBe("article")
  })

  it("is idempotent: a second run with the same posts sends nothing", async () => {
    const { kv, apns, run } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    await run([wp(11, "A")])
    const n = apns.calls.length
    await run([wp(11, "A")])
    expect(apns.calls.length).toBe(n)
  })

  it("duplicate prevention: a sent marker blocks a resend even if last-seen was lost", async () => {
    const { kv, apns, run } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    await run([wp(11, "A")])
    const n = apns.calls.length
    await kv.put(LAST_SEEN_KEY, "10") // simulate crash after sends, before last-seen saved
    await run([wp(11, "A")])
    expect(apns.calls.length).toBe(n)
    expect(await kv.get(LAST_SEEN_KEY)).toBe("11")
  })

  it("caps at 3 per run, oldest first; the rest wait for the next run", async () => {
    const { kv, apns, run } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    const posts = [15, 14, 13, 12, 11].map((i) => wp(i, `P${i}`))
    const r1 = await run(posts)
    expect(r1.processed).toEqual([11, 12, 13])
    expect(MAX_POSTS_PER_RUN).toBe(3)
    expect(await kv.get(LAST_SEEN_KEY)).toBe("13")
    const r2 = await run(posts)
    expect(r2.processed).toEqual([14, 15])
    expect(new Set(apns.calls.map((c) => JSON.parse(c.body).postId))).toEqual(new Set([11, 12, 13, 14, 15]))
  })

  it("deletes dead tokens and keeps tokens that merely failed transiently", async () => {
    const { kv, run } = await setup({ [TOKEN_A]: [[410, "Unregistered"]], [TOKEN_B]: [[503, "ServiceUnavailable"]] })
    await kv.put(LAST_SEEN_KEY, "10")
    await run([wp(11, "A")])
    expect(kv.data.has(`device:${TOKEN_A}`)).toBe(false)
    expect(kv.data.has(`device:${TOKEN_B}`)).toBe(true)
    expect(await kv.get(LAST_SEEN_KEY)).toBe("11")
  })

  it("site failure or non-JSON changes nothing", async () => {
    const { kv, apns } = await setup()
    await kv.put(LAST_SEEN_KEY, "10")
    for (const f of [
      (async () => new Response("nope", { status: 500 })) as unknown as typeof fetch,
      (async () => new Response("<html>")) as unknown as typeof fetch,
      (async () => { throw new Error("x") }) as unknown as typeof fetch,
    ]) {
      expect((await runPoll({ kv, fetchSite: f, send: apns.deps })).fetched).toBe(false)
    }
    expect(apns.calls.length).toBe(0)
    expect(await kv.get(LAST_SEEN_KEY)).toBe("10")
  })
})
