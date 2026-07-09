# Owner Privileges ("Daddy Mode") — v1.0

**Date:** 2026-07-09
**Branch baseline:** `docs/owner-privilege-spec` @ HEAD (forks from `main` at `a76c9e2`)
**Governs:** constitution §5 (Privacy & data handling), §6 (Security), §10.1 (accent/pill conventions), §10.2 (Title Case).
**Sibling docs:** [`spec.md`](spec.md), [`plan.md`](plan.md), [`backlog.md`](backlog.md).
**Tracking:** Parent **DUT-860**. Phase 1 = `feat/daddy-mode-phase1` + `feat/rank-rename-cast-iron-legend` (#579). Phase 2 = **DUT-861**, Phase 3 = **DUT-862**, Phase 4 = **DUT-863**, Phase 5 = **DUT-864** (3–5 blocked by 861).

## What this is

A design for granting **one specific account** — the app owner ("Dad", the site's WordPress admin) — a set of elevated, mostly-server-enforced privileges, while guaranteeing **no other account can obtain them**. It is security-critical: it introduces the app's first authorization boundary. The scope:

1. A per-user **Cook Rank** badge under the author name on comments.
2. A special **"The Dutch Oven Daddy"** owner badge on his profile and comments, authentic to *all* viewers.
3. A cosmetic **"Authentication successful. Daddy status confirmed."** message on his profile (view mode).
4. Owner-only **"Daddy's Tools"** → in-app **moderation** (view + delete offensive comments; more tools TBD).
5. Owner-only **app-exclusive posts**: author text + header + image + video, **save as draft / schedule / publish / delete**, served to every app user (not from the website).

## Security model (the non-negotiables)

- **Identity anchor = the Sign in with Apple `sub`** (`AppleAuthSession.userIdentifier`), the stable, Apple-issued, per-(user,app) identifier. **Never** gate on email (SIWA emails are private-relay and first-auth-only) and **never** on a client-typed value.
- **The client reveals UI; the backend enforces action.** Any operation that deletes data, publishes content, or renders a badge/rank to *other* users MUST be authorized server-side. Client-side gating is UX only and is assumed bypassable.
- **The owner allowlist lives server-side.** The `sub` is not a secret (it authorizes nothing on its own); its power comes only from being compared against a token whose signature was verified against Apple's public keys.
- **The app never holds privileged credentials.** No WordPress admin password, no Apple `.p8`, no service key ships in the binary. Privileged calls are proxied through a backend that holds those secrets.
- **Fail closed.** Unknown/unset owner → no privileges. Verification failure → deny.

### Current state (recon 2026-07-09)

- SIWA is captured (`AppleProfileSignInButton.swift`) but identity is **100% device-local**: the `sub` never leaves the device, and the Apple **`identityToken` (JWT) is never even read** — only the one-time `authorizationCode` (exchanged for a revoke-only refresh token) is used.
- The single Worker (`backend/siwa-revoke`) is **stateless**, has **no storage**, and authenticates callers with **one app-wide shared secret** (`X-DOD-App-Key`) that cannot distinguish users. It does **not** verify inbound user tokens.
- Comments live in **WordPress** (`/wp-json/wp/v2/`), posted with a **client-typed** `author_name`/`author_email`; `author_email` is **redacted on read**, so authorship is not verifiable from fetched data. No delete path exists.
- **No roles/permissions** exist anywhere. `ModerationBadge` is comment-lifecycle status, not a role.
- Cook Rank **exists** (`CookProgression.swift`) but is derived from the **local** cook log and shown only on the owner's own profile.

**Consequence:** server-enforced privileges are a build from zero. Phase 2 is the linchpin every later phase depends on.

## Phase 1 — Cosmetic "Daddy Mode" (no backend) — IN PROGRESS

Display-only, gated on the local `sub` via a new `OwnerGate` (placeholder owner `sub` → invisible to everyone until Dad's real value is set). Ships: the confirmation message, the standout **"The Dutch Oven Daddy"** owner badge (accent-filled `crown.fill` capsule) on his profile + his own comments, the **own-comment** Cook Rank badge (forward-compatible `CommentRow` params), and the revealed **Daddy's Tools** + **compose** entry points (honest placeholders). Also renames the top Cook Rank rung "Dutch Oven Daddy" → **"Cast Iron Legend"** to free the name for the owner badge. Enforces nothing.

**Activation:** replace `OwnerGate.ownerUserIdentifier` with Dad's real `sub`, captured once via the in-app diagnostic (long-press the Settings version footer → copies the current sign-in identifier). See "Sub capture" below.

## Phase 2 — Owner auth backend (linchpin) — DUT-861

Establish server-verified identity and an owner-authorization capability.

- **Client:** capture `credential.identityToken` at sign-in (currently discarded) alongside the existing `authorizationCode`. Store nothing new long-term beyond the session token below.
- **Worker `POST /session`:** verify the `identityToken` signature against Apple's JWKS (`https://appleid.apple.com/auth/keys`), validate `iss`/`aud`(bundle id)/`exp`, extract the verified `sub`, compare to a server-held **owner allowlist** (Worker secret/D1), and mint a **short-lived Worker-signed session JWT** carrying `{ sub, isOwner, exp }`. App stores it in Keychain; refreshes via re-auth or the existing refresh-token flow.
- **All privileged endpoints** (Phases 3–4) require this session JWT and re-check `isOwner` server-side.
- **Bootstrapping the allowlist:** Dad signs in once; his verified `sub` (from the first `/session` call, logged server-side, or captured via the Phase-1 diagnostic) is added to the allowlist by a trusted one-time step (Worker secret or a seeded D1 row). No self-service path to becoming owner.

**AC:** a forged/edited token, a valid non-owner token, and a missing token all yield `isOwner=false` / 401. Only a signature-valid token whose `sub` is on the allowlist yields an owner session.

## Phase 3 — In-app moderation — DUT-862 (blocked by Phase 2)

- **Worker `GET /moderation/recent-comments`** and **`DELETE /moderation/comments/{id}`**, both requiring an owner session (Phase 2). The Worker holds a **WordPress application password** (server secret) and proxies the WP admin delete; the app never sees WP creds.
- **App:** "Daddy's Tools" → a moderation list (reuse `CommentRow`) of recent comments across recipes/articles with a delete affordance and confirm. "Other moderation tools" (ban author, bulk actions, approve-queue) to be scoped as sub-tasks.

**AC:** delete works only with a valid owner session; a non-owner (or no) session is rejected server-side even if the client UI were forced open.

## Phase 4 — App-exclusive posts — DUT-863 (blocked by Phase 2)

- **Storage (new):** D1 for post records (`id`, `kind`, `title`, `headerImageKey`, `bodyBlocks`, `videoKey?`, `state`, `publishedAt`/`scheduledFor`/`draftSavedAt`, timestamps); **R2** for image/video blobs.
- **Worker (owner-auth writes, public reads):** CRUD + a `state` machine (`draft` → `scheduled` → `published`, plus `delete`); a scheduled trigger (Cron) promotes due `scheduled` posts to `published`. Public `GET /app-posts` returns published posts as a feed source.
- **iOS read:** a new client parallel to `WPRestClient`; merge into the feed at the `LiveFeedDependencies.fetchPosts` seam — **disjoint ID space** (so `FeedViewModel`'s id-dedup is unchanged) and **sort merged items by `publishedAt`**. Add an `isAppExclusive`/`source` field (additive `PostKind` case or `RecipeListItem.source`) via an additive-optional `CachedRecipe` migration. Pre-cache full detail so the detail screen's cache-hit branch serves them without attempting a WP HTML fetch.
- **iOS authoring (owner-only):** the `square.and.pencil` compose flow → header + rich text + image + video pickers; save draft / schedule / publish / delete. **Rendering reuses** `RecipeDetailVideoSection` (AVPlayer), `RecipeDetailHero`, `ArticleBlocksView`, and `ReliableImage`/`RecipeStore.cacheImage` — no new media stack.

**AC:** only an owner session can create/edit/publish/delete; drafts/scheduled posts are never returned by the public read; published app-exclusive posts appear in every user's feed, correctly ordered, and render text/header/image/video.

## Phase 5 — Cross-user badges on comments — DUT-864 (blocked by Phase 2; largest)

Make Cook Rank and the owner badge authentic on **other** users' comments.

- **Owner badge (lighter path):** have Dad's in-app comments post **as his authenticated WordPress user** (via the Phase-3 proxy) so they carry a real WP author id; other clients read it via `_embed=author` and render the owner badge on a server-truth match — no parallel identity needed.
- **Everyone's Cook Rank (heavier):** requires (a) each user's cook count server-side and (b) a comment→account linkage. Options: sync per-user cook totals to the backend keyed by verified `sub`, and attach a rank to each comment author server-side. This is a multiple of the other phases; recommend deferring until the backend and per-user identity are proven by Phases 2–4.

**AC:** the owner badge is spoof-proof (a user renaming themselves cannot obtain it); ranks shown for other users derive only from server-attested data.

## Open decisions

- **D1** — "Other moderation tools" beyond delete (ban author? approve-queue? bulk?).
- **D2** — Phase 5 per-user rank: build the per-user cook-count sync, or keep Cook-Rank-on-comments to own-comments-only indefinitely?
- **D3** — Backend platform confirmation (Cloudflare Worker + D1 + R2 assumed, matching the existing `backend/` layout) and cost ownership.
- **D4** — App Review posture: owner-authored media + moderation are owner-only; confirm no UGC-at-large obligations change.

## Sub capture (Phase-1 activation)

Dad signs in on his device (TestFlight or Xcode). To read his `sub`: **long-press the Settings version footer** → the current sign-in identifier copies to the clipboard with a "Diagnostic ID copied" toast (release-safe; the `sub` is opaque and non-authorizing). He sends it over; we set `OwnerGate.ownerUserIdentifier` and (Phase 2+) seed the server allowlist. The diagnostic can be removed or left as a harmless support affordance.
