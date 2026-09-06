#!/usr/bin/env bash
# Exposes the local API on a public HTTPS address so phones off this Wi-Fi
# can reach it. Free, no Cloudflare account needed.
#
# The URL changes every restart — that is why the app has an editable
# "Server" field in Settings rather than a baked-in address.
set -e
source "$(dirname "$0")/env.sh"

command -v "$HOME/bin/cloudflared" >/dev/null 2>&1 || {
  echo "cloudflared not found at ~/bin/cloudflared"; exit 1; }

curl -s --max-time 5 http://127.0.0.1:4000/health >/dev/null || {
  echo "The API is not running. Start it first: ./scripts/api-start.sh"; exit 1; }

# --protocol http2 because QUIC/UDP is throttled on many networks, which
# shows up as "timeout: no recent network activity" and a dead tunnel.
echo "Starting tunnel (http2)…"
"$HOME/bin/cloudflared" tunnel --protocol http2 --url http://127.0.0.1:4000 2>&1 \
  | tee /tmp/cloudflared.log &

for _ in $(seq 1 40); do
  URL=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" /tmp/cloudflared.log 2>/dev/null | head -1)
  [ -n "$URL" ] && break
  sleep 3
done

if [ -z "${URL:-}" ]; then echo "Could not obtain a tunnel URL."; exit 1; fi
echo ""
echo "  Public API:  $URL"
echo "  Put that in the app under Settings -> Server -> Test and save."
echo ""
echo "Leave this running. Ctrl-C stops the tunnel."
wait
