# New recipe / article push Worker (DUT-1397)

A Cloudflare Worker that sends an APNs alert push to every registered device
within about 2 minutes of a new recipe or article appearing on dutchovendaddy.com.

- **Cron (every 2 minutes):** fetches the 10 newest posts from the public WordPress API
  (`/wp-json/wp/v2/posts`), compares with the last-seen post id in KV, and pushes each
  new post (oldest first, at most 3 per run) to devices whose matching flag is on.
- **First run** only records a baseline and sends nothing.
- **Duplicates:** a `sent:<postId>` marker is written after the sends for a post were
  attempted, then the last-seen id advances. A crash mid-run re-processes at most that post.
- **Dead tokens** (APNs 410, `BadDeviceToken`, `Unregistered`) are removed automatically.
  429/5xx are retried once; if still failing, that device misses that post.

| Endpoint | Body | Response |
|----------|------|----------|
| `POST /register` | `{token, environment: "production"\|"development", bundleId, appVersion, newRecipes, newArticles}` | `{registered:true}` (idempotent) |
| `DELETE /register` | `{token}` | `{removed:true}` |
| `POST /test` | `{token, environment?}` | `{status, reason}` exactly as APNs answered |
| `GET /health` | none | `{devices:{production, development, total}}` |

Every request needs header `X-App-Secret: <APP_SHARED_SECRET>` (constant-time compare).
`token` is the 64 to 200 char hex device token.

### Recipe vs article

Every post from the API has `type: "post"`, so type cannot tell them apart. A post is an
**article** if it is in category **1432 "Cast Iron Care"** (or its type is not `post`);
everything else is a **recipe** (the default). See `postKind()` in `src/posts.ts`.

## Owner steps

1. **APNs key.** developer.apple.com/account/resources/authkeys/list > **Keys** > **+** >
   name it (e.g. "DOD Push"), enable **Apple Push Notifications service (APNs)**, Continue,
   Register, **Download the `.p8`** (one-time download). Note the **Key ID** (10 chars) and your
   **Team ID** (top right of the portal). One key works for both sandbox and production.
2. `npx wrangler login`
3. `cd backend/new-recipe-push && ./deploy.sh` - it installs, creates the KV namespace, pauses
   so you can paste the KV id, `APNS_KEY_ID` and `APNS_TEAM_ID` into `wrangler.toml`, deploys,
   then prompts for the two secrets (`APNS_PRIVATE_KEY` = full `.p8` contents, `APP_SHARED_SECRET`
   = a long random string).

   Manual equivalent:
   ```bash
   cd backend/new-recipe-push && npm install
   npx wrangler kv namespace create DEVICES      # paste the id into wrangler.toml
   # fill APNS_KEY_ID + APNS_TEAM_ID in wrangler.toml
   npx wrangler deploy
   npx wrangler secret put APNS_PRIVATE_KEY
   npx wrangler secret put APP_SHARED_SECRET
   ```
4. **Put two values in the iOS app:** the Worker URL printed by deploy
   (`https://dod-new-recipe-push.<you>.workers.dev`) and the same `APP_SHARED_SECRET`
   (sent as `X-App-Secret`).

## Verify

```bash
curl -sS $URL/health -H "X-App-Secret: $SECRET"
curl -sS -X POST $URL/test -H "X-App-Secret: $SECRET" -H 'Content-Type: application/json' \
  -d '{"token":"<device token>","environment":"development"}'   # -> {"status":200,"reason":null}
npx wrangler tail    # watch cron runs and per-failure status/reason (tokens are redacted)
```

## Notes

- Free Workers plan allows 50 subrequests per invocation (each APNs send and KV call counts), so
  roughly 40 devices per post. Use Workers Paid (1000) for a real audience.
- Posts are detected by id greater than the last-seen id, so a very old draft published late (lower
  id) is not announced.
- The JWT is cached 50 minutes per isolate; a 403 from APNs drops the cache.

## Tests

`npm install && npm test` (vitest) and `npm run typecheck`.
