#!/usr/bin/env bash
# Starts the local Postgres cluster (portable build, no root needed).
set -e
source "$(dirname "$0")/env.sh"
if "$PGDIR/bin/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  echo "Postgres already running on port $PGPORT"
  exit 0
fi
"$PGDIR/bin/pg_ctl" -D "$PGDATA" -l /home/sujeeth_26/pgsql/pg.log \
  -o "-p $PGPORT -k $PGRUN -c listen_addresses=127.0.0.1" start
echo "Postgres up on 127.0.0.1:$PGPORT"
