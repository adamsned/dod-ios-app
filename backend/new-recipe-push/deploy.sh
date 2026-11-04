#!/usr/bin/env bash
# One-shot deploy of the new recipe / article push Worker (DUT-1397).
#
# Prereqs:
#   - A Cloudflare account ( `npx wrangler login` once ).
#   - An APNs key (.p8) + its Key ID + your Team ID
#     (Apple Developer portal: Keys > + > Apple Push Notifications service).
#
# Run:  cd backend/new-recipe-push && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Installing dependencies"
npm install

echo
echo "==> Creating the KV namespace (skip the paste step if wrangler.toml already has a real id)"
npx wrangler kv namespace create DEVICES || true
echo
echo "==> Edit wrangler.toml now: set the KV namespace id, APNS_KEY_ID and APNS_TEAM_ID"
echo "    (APNS_TOPIC is already the bundle id com.dutchovendaddy.DODApp)."
read -rp "    Press Enter once wrangler.toml is filled in... "

echo
echo "==> Deploying the Worker"
npx wrangler deploy

echo
echo "==> Setting the two encrypted secrets (values are prompted; never written to the repo)"
echo "    APNS_PRIVATE_KEY - paste the FULL .p8 contents (including the BEGIN/END lines):"
npx wrangler secret put APNS_PRIVATE_KEY
echo "    APP_SHARED_SECRET - a long random string (the iOS app sends the SAME value as X-App-Secret):"
npx wrangler secret put APP_SHARED_SECRET

echo
echo "==> Done. Two values go into the iOS app:"
echo "    1. The Worker URL printed above (https://dod-new-recipe-push.<you>.workers.dev)."
echo "    2. The APP_SHARED_SECRET you just set."
echo "    Sanity-check:  curl -sS \"\$WORKER_URL/health\" -H \"X-App-Secret: \$APP_SHARED_SECRET\""
