# Social Layer — from recipe book to community — v1.0

**Date:** 2026-07-11
**Owner:** Ned Adams (Dad) — strategic direction + the ops/privacy decisions this depends on.
**Governs:** constitution §5 (Privacy & data handling), §6 (Security).
**Builds on:** [`owner-privileges.md`](owner-privileges.md) — the Phase 2 authenticated backend (DUT-861) is the shared foundation.
**Tracking:** parent **DUT-951**; children **DUT-952…956** (filed under team *Dutch Oven Daddy*, assigned to Ned).

## Vision

Turn Dutch Oven Daddy from a **recipe book** into a **social experience**: users have real profiles, they can see each other (Cook Rank, cook stats) on comments, tap through to a commenter's profile, and moderate their own experience (block/report). This is groundwork — once per-user identity + a real backend exist, everything downstream (following, notifications, richer profiles, owner-published content) becomes possible. These are important features; the recipe book is the seed, the social layer is the app.

## The hard truth about the current app

The app today is deliberately **local-first with no user backend**: profiles, cook logs, and all stats (Total Cooks, Weekly Streak, Cook Rank, Saved, Ratings) are computed from the **device's own SwiftData cook log** and exist only for the current user, on their own device. Comments are **anonymous** WordPress comments (name + Gravatar; email redacted on read; no account id). The only server-side component is a stateless Sign-in-with-Apple revoke Worker that isn't even deployed yet.

**Consequence:** you cannot show *another* user's stats, rank, or a real profile today — that data does not exist anywhere the app can reach. Every social feature below therefore depends on first building a per-user identity + data backend.

## The four building blocks (in order)

1. **Per-user authenticated backend (DUT-952).** Generalize the Phase 2 owner-auth (DUT-861) to *every* user: capture Apple's `identityToken`, a Cloudflare Worker verifies it against Apple's JWKS and issues a session, and each signed-in user gets a server-verified identity (`sub`) + an account record (D1). This is the foundation; nothing else works without it. ~1 week of code + the ops gate.

2. **Per-user stats sync (DUT-953).** The device's cook-log-derived stats sync up to the backend keyed by the verified identity, so they can be served for others. This is the step with the heaviest **non-engineering** weight: it moves users' cooking activity from local-only to server-stored — a real privacy-posture change requiring a privacy-policy update, App Store data-collection disclosures, and likely consent UX. Blocked by DUT-952.

3. **Comment → account linkage (DUT-954).** Comments must carry a **stable verified account id** so a commenter can be resolved to their account/stats. Today comments are anonymous WP; this means posting comments through the backend (or as authenticated WP users) so they're stamped with the identity. Touches the whole comment post/read path. Blocked by DUT-952.

4. **Commenter profiles + public stats API (DUT-955).** A `GET /users/{id}/public-stats` returning the shareable subset (Cook Rank, cook count, streak — **never** email), plus the app UI: tap a comment's name/avatar → a profile sheet showing that user's stats *like your own*, with **Block** and **Report** replacing Sign Out / Delete, and email never shown. Blocked by DUT-953 + DUT-954.

## Near-term win (no backend) — DUT-956

The **interaction half** of the commenter profile is doable today: make a comment's name/avatar tappable → a "commenter" sheet showing their name + Gravatar avatar and **Block / Report** (reusing the existing `CommentModerationStore` + the long-press `canModerate`/`reportComment`/`blockAuthor` actions in `RecipeDetailRatingsSection+PhaseD.swift`). No stats (that data doesn't exist for others yet), but it promotes the hidden long-press into a real tappable profile and ships now. Upgrades cleanly into DUT-955 once the backend lands.

## Cheaper 80/20 alternative (optional, no per-user backend)

**Snapshot the commenter's stats onto the comment itself** — the author's Cook Rank / cook count ride along as comment metadata when they post (the way the star rating already does), so any client reads it straight off the comment. No stats sync, no per-user backend. Trade-offs: it's a **snapshot at post-time** (an old comment shows their rank *then*, not now), it's **self-reported/unverified** (fine for a cosmetic badge, not trust-sensitive), and it needs WordPress to store + return that comment meta. Useful if the goal is just "a rank badge on commenter cards" cheaply; upgrade to the real backend (DUT-953+) later.

## The gates that aren't code

- **Ops / provisioning:** a Cloudflare account, Apple sign-in keys (`.p8`, Key ID, Team ID, bundle/Services ID), and storage (D1) — someone must own and run it. This is the same first domino as Phase 2 and gates everything. **Ned's call.**
- **Privacy & App Review:** storing users' cooking activity + a social graph server-side is a genuine change from today's local/private model. New privacy policy, App Store data-collection disclosures, likely consent UX. **Product/legal decision — Ned's call.**
- **Cost & maintenance:** moving from zero backend to a real service to run and maintain, ongoing.

## Effort

- Per-user backend (DUT-952): ~1 week code + the ops gate.
- Full "everyone's stats on comments/profiles" (DUT-952→955): on the order of **~1 month** of focused work + the privacy/compliance overhead.
- Near-term commenter sheet (DUT-956): small, ships now, no backend.

## Open decisions

- **D1** — Who owns the Cloudflare account + Apple keys? (The gating prerequisite for all backend work.)
- **D2** — Privacy posture: are we willing to store per-user cooking activity server-side? (Gates DUT-953.) If not, the snapshot-on-comment alternative is the only path to visible stats.
- **D3** — Comment identity: post comments through our backend vs. authenticated WordPress users. (Affects DUT-954.)
- **D4** — Session JWT signing (HMAC vs keypair); stats store shape (D1 schema).

## What this unlocks (why it's groundwork, not a one-off)

Once per-user identity + a stats backend exist, the app can grow into: following/followers, activity feeds, richer public profiles, owner-published content attributed to real accounts (ties to owner-privileges Phase 4), notifications, and trustworthy badges/leaderboards. The commenter profile is the first visible piece; the backend is the platform the rest stands on.
