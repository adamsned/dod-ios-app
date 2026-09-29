#!/usr/bin/env bash
# One-shot deploy of the Grocery order Worker (DUT-532).
#
# Prereqs:
#   - A Cloudflare account ( `npx wrangler login` once ).
#   - An Instacart IDP (Developer Platform) API key. Point INSTACART_BASE_URL at
#     the sandbox host for a sandbox key, or the prod host for a prod key.
#   - (Optional) a Walmart affiliate id for the fallback search links.
#
# Run:  cd backend/grocery-order && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Installing dependencies"
npm install

echo
echo "==> Edit wrangler.toml now: set INSTACART_BASE_URL under [vars]"
echo "    (prod: https://connect.instacart.com — sandbox: https://connect.dev.instacart.tools)."
echo "    Optionally set WALMART_AFFILIATE_ID for the Walmart fallback links."
read -rp "    Press Enter once wrangler.toml is filled in... "

echo
echo "==> Deploying the Worker"
npx wrangler deploy

echo
echo "==> Setting the encrypted secrets (values are prompted; never written to the repo)"
echo "    DOD_APP_KEY — a long random string (put the SAME value in the app's DODGroceryEndpoint config):"
npx wrangler secret put DOD_APP_KEY
echo "    INSTACART_API_KEY — the Instacart IDP API key (Bearer):"
npx wrangler secret put INSTACART_API_KEY

echo
echo "==> Done. Final steps:"
echo "    1. Copy the Worker URL printed above into the app's DODGroceryEndpoint config"
echo "       and set the shared X-DOD-App-Key to the SAME value as DOD_APP_KEY."
echo "    2. Enable the providers you want in DODGroceryProviders (instacart / walmart_plus)."
echo "    Then sanity-check the Walmart fallback (no vendor key needed):"
echo "       curl -sS -X POST \"\$WORKER_URL/\" \\"
echo "         -H \"X-DOD-App-Key: \$DOD_APP_KEY\" -H 'Content-Type: application/json' \\"
echo "         -d '{\"provider\":\"walmart_plus\",\"title\":\"Test\",\"line_items\":[{\"name\":\"onion\"}]}'"
echo "       # -> {\"products_link_url\":\"https://www.walmart.com/search?q=onion\"}"
