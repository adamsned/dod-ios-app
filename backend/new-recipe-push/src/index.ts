// Dutch Oven Daddy - new recipe / article push sender (DUT-1397).
//
//   POST   /register  device registration (X-App-Secret)
//   DELETE /register  device removal      (X-App-Secret)
//   POST   /test      send one test push  (X-App-Secret)
//   GET    /health    device counts       (X-App-Secret)
//   cron   */2 * * * *  poll WordPress, push new posts via APNs
import { isAuthorized } from "./auth"
import { makeDeps, sendPush, type ApnsEnv } from "./apns"
import { deleteDevice, listDevices, saveDevice, validateRegistration, validateToken } from "./devices"
import { runPoll } from "./poll"

export interface Env extends ApnsEnv {
  DEVICES: KVNamespace
  APP_SHARED_SECRET: string
}

const MAX_BODY_BYTES = 4096

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, env)
    } catch (err) {
      console.error("new-recipe-push server_error", err instanceof Error ? err.name : "unknown")
      return json({ error: "server_error" }, 500)
    }
  },

  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(
      runPoll({ kv: env.DEVICES, fetchSite: (...a) => fetch(...a), send: makeDeps(env) })
        .then((r) => console.log(`poll fetched=${r.fetched} baseline=${r.baseline ?? false} processed=${r.processed.length}`))
        .catch((err) => console.error("poll_failed", err instanceof Error ? err.name : "unknown"))
    )
  },
}

async function route(request: Request, env: Env): Promise<Response> {
  const { pathname } = new URL(request.url)
  const known = ["/register", "/test", "/health"]
  if (!known.includes(pathname)) return json({ error: "not_found" }, 404)
  if (!(await isAuthorized(request.headers.get("X-App-Secret"), env.APP_SHARED_SECRET))) {
    return json({ error: "unauthorized" }, 401)
  }
  const m = request.method

  if (pathname === "/health" && m === "GET") {
    const devices = await listDevices(env.DEVICES)
    const production = devices.filter((d) => d.environment === "production").length
    return json({ devices: { production, development: devices.length - production, total: devices.length } })
  }
  if (pathname === "/register" && m === "POST") {
    const body = await readJson(request)
    const reg = validateRegistration(body)
    if (!reg.ok) return json({ error: reg.error }, 400)
    await saveDevice(env.DEVICES, reg.value, Date.now())
    return json({ registered: true })
  }
  if (pathname === "/register" && m === "DELETE") {
    const token = validateToken(((await readJson(request)) as { token?: unknown } | null)?.token)
    if (!token.ok) return json({ error: token.error }, 400)
    await deleteDevice(env.DEVICES, token.value)
    return json({ removed: true })
  }
  if (pathname === "/test" && m === "POST") {
    const body = (await readJson(request)) as { token?: unknown; environment?: unknown } | null
    const token = validateToken(body?.token)
    if (!token.ok) return json({ error: token.error }, 400)
    let environment = body?.environment
    if (environment === undefined) {
      environment = (await listDevices(env.DEVICES)).find((d) => d.token === token.value)?.environment ?? "production"
    }
    if (environment !== "production" && environment !== "development") return json({ error: "invalid_environment" }, 400)
    const result = await sendPush(
      makeDeps(env),
      { token: token.value, environment },
      { aps: { alert: { title: "Dutch Oven Daddy", body: "Test push: notifications are working" }, sound: "default" } }
    )
    return json({ status: result.status, reason: result.reason ?? null })
  }
  return json({ error: "method_not_allowed" }, 405)
}

async function readJson(request: Request): Promise<unknown> {
  const text = await request.text()
  if (text.length > MAX_BODY_BYTES) return null
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

