#!/usr/bin/env bash
# One-shot deploy of the Sign in with Apple revoke Worker (DUT-98 / T-797).
#
# Prereqs:
#   - A Cloudflare account ( `npx wrangler login` once ).
#   - Your Sign in with Apple .p8 key + its Key ID + your Team ID
#     (create the Key at developer.apple.com/account/resources/authkeys/list).
#
# Run:  cd backend/siwa-revoke && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Installing dependencies"
npm install

echo
echo "==> Edit wrangler.toml now: set APPLE_KEY_ID and APPLE_TEAM_ID under [vars]"
echo "    (APPLE_CLIENT_ID is already the bundle id com.dutchovendaddy.DODApp)."
read -rp "    Press Enter once wrangler.toml is filled in... "

echo
echo "==> Deploying the Worker"
npx wrangler deploy

echo
echo "==> Setting the two encrypted secrets (values are prompted; never written to the repo)"
echo "    APPLE_PRIVATE_KEY — paste the FULL .p8 contents (including the BEGIN/END lines):"
npx wrangler secret put APPLE_PRIVATE_KEY
echo "    APP_SHARED_SECRET — a long random string (the SAME value goes in the SIWA_REVOKE_APP_SECRET GitHub secret):"
npx wrangler secret put APP_SHARED_SECRET

echo
echo "==> Done. Two final steps:"
echo "    1. gh secret set SIWA_REVOKE_BASE_URL     # the Worker URL printed above"
echo "    2. gh secret set SIWA_REVOKE_APP_SECRET   # the same APP_SHARED_SECRET"
echo "    Then sanity-check:  curl -sS -X POST \"\$WORKER_URL/revoke\" \\"
echo "       -H \"X-DOD-App-Key: \$APP_SHARED_SECRET\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"refreshToken\":\"not-a-real-token\"}'   # -> {\"revoked\":true}"
