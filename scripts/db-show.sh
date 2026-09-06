#!/usr/bin/env bash
# Look inside the database. There is no psql in the portable Postgres bundle,
# so this goes through the API's own pg connection.
#
#   ./scripts/db-show.sh                     summary + recent reports
#   ./scripts/db-show.sh problems            every report
#   ./scripts/db-show.sh devices             registered devices
#   ./scripts/db-show.sh media               uploaded evidence
#   ./scripts/db-show.sh history JH-DMK-000417
#   ./scripts/db-show.sh sql "SELECT ..."    any read-only query
set -e
source "$(dirname "$0")/env.sh"
cd "$SANGAM_ROOT/sangam_api"
node src/show.js "$@"
