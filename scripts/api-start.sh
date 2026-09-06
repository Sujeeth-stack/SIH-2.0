#!/usr/bin/env bash
# Starts Postgres if needed, applies migrations, then runs the API.
set -e
source "$(dirname "$0")/env.sh"
"$(dirname "$0")/db-start.sh"
cd "$SANGAM_ROOT/sangam_api"
node src/migrate.js
node src/seed.js
echo "--- starting API on :4000 (Ctrl-C to stop) ---"
node src/server.js
