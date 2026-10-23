import { describe, expect, it } from "vitest"
import { buildPayload, decodeEntities, fetchPosts, parsePosts, postKind } from "../src/posts"

describe("postKind", () => {
  it("Cast Iron Care category (1432) is an article", () => {
    expect(postKind({ type: "post", categories: [1432, 1441, 1590] })).toBe("article")
    expect(postKind({ type: "post", categories: [1432] })).toBe("article")
  })
  it("recipe categories, roundups and unknowns default to recipe", () => {
    expect(postKind({ type: "post", categories: [339, 1590] })).toBe("recipe")
    expect(postKind({ type: "post", categories: [1441, 1590, 1319] })).toBe("recipe")
    expect(postKind({ type: "post", categories: [] })).toBe("recipe")
    expect(postKind({})).toBe("recipe")
  })
  it("a non-post type (page) is an article", () => {
    expect(postKind({ type: "page", categories: [] })).toBe("article")
  })
})

describe("decodeEntities", () => {
  it("decodes numeric, hex and named entities and strips tags", () => {
    expect(decodeEntities("Mac &amp; Cheese &#8211; Mom&#8217;s")).toBe("Mac & Cheese – Mom’s")
    expect(decodeEntities("A&#x27;B &quot;q&quot; <b>bold</b>")).toBe("A'B \"q\" bold")
    expect(decodeEntities("&unknown; &#99999999;")).toBe("&unknown; &#99999999;")
  })
})

describe("parsePosts / fetchPosts", () => {
  it("drops malformed entries and decodes titles", () => {
    const posts = parsePosts([{ id: 5, title: { rendered: "Fish &amp; Chips" }, type: "post", categories: [1] }, { id: "x" }, null, { id: -1 }])
    expect(posts).toEqual([{ id: 5, title: "Fish & Chips", type: "post", categories: [1] }])
    expect(parsePosts({ not: "array" })).toEqual([])
  })
  it("returns null quietly on network error, non-200, and non-JSON", async () => {
    expect(await fetchPosts((async () => { throw new Error("down") }) as unknown as typeof fetch)).toBeNull()
    expect(await fetchPosts((async () => new Response("x", { status: 503 })) as unknown as typeof fetch)).toBeNull()
    expect(await fetchPosts((async () => new Response("<html>")) as unknown as typeof fetch)).toBeNull()
  })
})

describe("buildPayload", () => {
  it("has the exact documented shape", () => {
    const p = { id: 7, title: "Soup", type: "post", categories: [] }
    expect(buildPayload(p, "recipe")).toEqual({ aps: { alert: { title: "Soup", body: "A new recipe just dropped" }, sound: "default" }, postId: 7, postKind: "recipe" })
    expect(buildPayload(p, "article").aps.alert.body).toBe("A new article just dropped")
  })
})
