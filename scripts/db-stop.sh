#!/usr/bin/env bash
set -e
source "$(dirname "$0")/env.sh"
"$PGDIR/bin/pg_ctl" -D "$PGDATA" stop -m fast
