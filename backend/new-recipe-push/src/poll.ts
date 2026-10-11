// Scheduled work: detect new posts and push them.
import { mapLimit, sendPush, type SendDeps } from "./apns"
import { deleteDevice, listDevices } from "./devices"
import { buildPayload, fetchPosts, postKind } from "./posts"

export const LAST_SEEN_KEY = "meta:lastSeenId"
export const SENT_PREFIX = "sent:"
export const MAX_POSTS_PER_RUN = 3
export const CONCURRENCY = 20
const SENT_TTL_SECONDS = 30 * 24 * 60 * 60

export interface PollDeps {
  kv: KVNamespace
  fetchSite: typeof fetch
  send: SendDeps
}

export interface PollResult {
  baseline?: boolean
  fetched: boolean
  processed: number[]
}

export async function runPoll(deps: PollDeps): Promise<PollResult> {
  const posts = await fetchPosts(deps.fetchSite)
  if (!posts) return { fetched: false, processed: [] }

  const stored = await deps.kv.get(LAST_SEEN_KEY)
  const lastSeen = stored === null ? NaN : Number(stored)
  if (!Number.isInteger(lastSeen)) {
    // First run: remember where we are, notify nobody.
    if (posts.length > 0) await deps.kv.put(LAST_SEEN_KEY, String(Math.max(...posts.map((p) => p.id))))
    return { baseline: true, fetched: true, processed: [] }
  }

  // Oldest first, capped; anything beyond the cap stays > lastSeen for the next run.
  const fresh = posts
    .filter((p) => p.id > lastSeen)
    .sort((a, b) => a.id - b.id)
    .slice(0, MAX_POSTS_PER_RUN)
  if (fresh.length === 0) return { fetched: true, processed: [] }

  const devices = await listDevices(deps.kv)
  const processed: number[] = []
  for (const post of fresh) {
    if ((await deps.kv.get(SENT_PREFIX + post.id)) === null) {
      const kind = postKind(post)
      const targets = devices.filter((d) => (kind === "recipe" ? d.newRecipes : d.newArticles))
      const payload = buildPayload(post, kind)
      const results = await mapLimit(targets, CONCURRENCY, (d) => sendPush(deps.send, d, payload, `post-${post.id}`))
      await Promise.all(targets.filter((_, i) => results[i].outcome === "dead").map((d) => deleteDevice(deps.kv, d.token)))
      console.log(`push post=${post.id} kind=${kind} targets=${targets.length} ok=${results.filter((r) => r.outcome === "ok").length}`)
      // Only after every send was attempted: marker first, then the high-water mark.
      await deps.kv.put(SENT_PREFIX + post.id, "1", { expirationTtl: SENT_TTL_SECONDS })
    }
    await deps.kv.put(LAST_SEEN_KEY, String(post.id))
    processed.push(post.id)
  }
  return { fetched: true, processed }
}
