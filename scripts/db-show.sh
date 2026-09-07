#!/usr/bin/env bash
# Look inside the database. There is no psql in the portable Postgres bundle,
# so this goes through the API's own pg connection.
#
# Which database it reads:
#   default   the Render (live) database, when RENDER_DATABASE_URL is set
#   --local   the portable cluster on this laptop
#   --remote  force live, and fail loudly if it is not configured
#
# It always prints which one it used first, because reading the local database
# while the app writes to Render is a very easy way to think data is missing.
#
#   ./scripts/db-show.sh                      counts, statuses, recent reports
#   ./scripts/db-show.sh problems             every report
#   ./scripts/db-show.sh devices              who has reported, and how much
#   ./scripts/db-show.sh media                uploaded evidence
#   ./scripts/db-show.sh history JH-DMK-000417
#   ./scripts/db-show.sh sql "SELECT ..."     any read-only query
#   ./scripts/db-show.sh --local summary
set -e
source "$(dirname "$0")/env.sh"

TARGET=auto
case "${1:-}" in
  --local|-l)  TARGET=local;  shift ;;
  --remote|-r) TARGET=remote; shift ;;
esac

if [ "$TARGET" = "remote" ] && [ -z "${RENDER_DATABASE_URL:-}" ]; then
  echo "RENDER_DATABASE_URL is not set." >&2
  echo "Put it in sangam_api/.env — see sangam_api/.env.example." >&2
  exit 1
fi

if [ "$TARGET" != "local" ] && [ -n "${RENDER_DATABASE_URL:-}" ]; then
  export DATABASE_URL="$RENDER_DATABASE_URL"
  # db.js prefers DATABASE_URL, but clear these so nothing can fall back to
  # the laptop's cluster half way through.
  unset PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE
  HOST=$(printf '%s' "$DATABASE_URL" | sed -E 's|.*@([^/:]+).*|\1|')
  echo "reading: LIVE (Render) — $HOST"
else
  echo "reading: LOCAL — 127.0.0.1:${PGPORT:-5433}"
  if [ -z "${RENDER_DATABASE_URL:-}" ]; then
    echo "         (set RENDER_DATABASE_URL in sangam_api/.env to read the live database)"
  fi
fi
echo ""

cd "$SANGAM_ROOT/sangam_api"
node src/show.js "$@"
