# Universal Links runbook (DUT-1325)

Goal: a tapped **dutchovendaddy.com** link (Messages, Mail, social, a newsletter)
opens in the app on the matching recipe/article when the app is installed, and in
Safari otherwise.

The app half ships in this repo. Two operational steps below are **not** app code —
they need the Apple Developer account and the WordPress site. **Until both are
done, links keep opening in Safari** (the app-side handler is inert but harmless).

## Status checklist

- [x] App: handle the incoming web URL (`RootView` → `openRecipeLink`) — this PR
- [x] App: `applinks:` Associated Domains entitlement — this PR
      (`App/DODApp.entitlements`)
- [ ] **Apple Developer portal:** enable "Associated Domains" on App ID
      `com.dutchovendaddy.DODApp`, regenerate the provisioning profile, ship a
      signed build (TestFlight/App Store). Automatic signing can't provision
      `applinks` until the capability is on the App ID.
- [ ] **WordPress:** host the AASA file (below) at both hosts.

## The AASA file

Serve `Marketing/apple-app-site-association` (in this repo) at **both**:

- `https://dutchovendaddy.com/.well-known/apple-app-site-association`
- `https://www.dutchovendaddy.com/.well-known/apple-app-site-association`

Requirements iOS enforces:

- **HTTPS, no redirect.** The URL must return `200` directly — a 301/302 (e.g.
  apex → www) breaks verification. Serve the file on each host independently.
- **`Content-Type: application/json`.**
- **No file extension** (`apple-app-site-association`, not `.json`).
- **Raw JSON**, not an HTML page. Verify with
  `curl -sI https://www.dutchovendaddy.com/.well-known/apple-app-site-association`
  (expect `content-type: application/json`) and
  `curl -s …/apple-app-site-association | head` (expect the JSON, not `<!DOCTYPE html>`).

### Fill in the Team ID

Replace `TEAMID` in the file with the **Apple Developer Team ID** (App Store
Connect / Developer portal → Membership). The `appID` becomes
`<TEAM_ID>.com.dutchovendaddy.DODApp`.

### Paths

`"/*"` matches every post permalink (DOD uses flat `/<slug>/`). The `NOT` rules
above exclude wp-admin, the REST API, category/tag/author/feed archives, and
`.well-known` itself so those still open on the web. Tighten later if we only want
recipe/article permalinks to deep-link.

### Hosting on WordPress

WordPress has no `.well-known/` file by default. Options, easiest first:

1. A Universal-Links / AASA plugin (serves the file at the well-known path).
2. A physical file at the web root: `.well-known/apple-app-site-association`
   (ensure the server sends `application/json` and doesn't 404 the extensionless
   file — some hosts need an `.htaccess`/nginx rule for the MIME type).
3. A small must-use plugin that hooks an `init` rewrite to emit the JSON.

## Testing (device only)

Universal Links can't be exercised on the Simulator (unsigned builds strip
entitlements; no AASA fetch). On a signed device build with both steps live:

1. Apple's CDN caches the AASA at install time. After hosting it, delete + reinstall
   the app (or use a fresh TestFlight install) so the device re-fetches.
2. Tap a `https://www.dutchovendaddy.com/<recipe-slug>/` link from **Messages** or
   **Notes** (Safari's address bar deliberately does NOT trigger Universal Links;
   long-press the link → "Open in Dutch Oven Daddy" is the tell).
3. It should land on that recipe/article in-app. A link to a non-post page
   (e.g. a WP page) still opens in Safari — that's the intended fallback.

Apple's validator: <https://search.developer.apple.com/appsearch-validation-tool/>
