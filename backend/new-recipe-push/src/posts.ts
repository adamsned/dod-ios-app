// WordPress post fetching + classification + push payload.
export const POSTS_URL =
  "https://dutchovendaddy.com/wp-json/wp/v2/posts?per_page=10&_fields=id,title,link,date_gmt,type,categories"

export type PostKind = "recipe" | "article"

export interface Post {
  id: number
  title: string // decoded plain text
  type: string
  categories: number[]
}

// Category 1432 = "Cast Iron Care" (guides, buying advice, restoration how-tos).
export const ARTICLE_CATEGORY_ID = 1432

// Rule: a post is an ARTICLE when its WP type is not "post" (e.g. a page) or it
// is in the "Cast Iron Care" category (1432). Everything else - including
// roundup posts - is a RECIPE (default). The public API returns type "post"
// for every item and has no separate "article" post type or category, so the
// category is the only reliable signal on this site.
export function postKind(post: { type?: string; categories?: number[] }): PostKind {
  if (post.type && post.type !== "post") return "article"
  return post.categories?.includes(ARTICLE_CATEGORY_ID) ? "article" : "recipe"
}

const NAMED: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", rsquo: "’", lsquo: "‘",
  rdquo: "”", ldquo: "“", ndash: "–", mdash: "—", hellip: "…",
}

export function decodeEntities(s: string): string {
  return s
    .replace(/<[^>]*>/g, "")
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
      if (e[0] === "#") {
        const cp = e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)
        return Number.isFinite(cp) && cp > 0 && cp <= 0x10ffff ? String.fromCodePoint(cp) : m
      }
      return NAMED[e.toLowerCase()] ?? m
    })
    .trim()
}

export function parsePosts(data: unknown): Post[] {
  if (!Array.isArray(data)) return []
  const posts: Post[] = []
  for (const p of data) {
    if (typeof p !== "object" || p === null) continue
    const r = p as Record<string, unknown>
    if (typeof r.id !== "number" || !Number.isInteger(r.id) || r.id <= 0) continue
    const rendered = (r.title as { rendered?: unknown } | undefined)?.rendered
    posts.push({
      id: r.id,
      title: typeof rendered === "string" ? decodeEntities(rendered) : "",
      type: typeof r.type === "string" ? r.type : "post",
      categories: Array.isArray(r.categories) ? r.categories.filter((c): c is number => Number.isInteger(c)) : [],
    })
  }
  return posts
}

// Quiet on every failure: network error, non-200, non-JSON -> null.
export async function fetchPosts(fetchFn: typeof fetch): Promise<Post[] | null> {
  try {
    const resp = await fetchFn(POSTS_URL, { signal: AbortSignal.timeout(10_000), headers: { Accept: "application/json" } })
    if (!resp.ok) return null
    return parsePosts(await resp.json())
  } catch {
    return null
  }
}

export function buildPayload(post: Post, kind: PostKind) {
  return {
    aps: {
      alert: {
        title: post.title || "Dutch Oven Daddy",
        body: kind === "recipe" ? "A new recipe just dropped" : "A new article just dropped",
      },
      sound: "default",
    },
    postId: post.id,
    postKind: kind,
  }
}
