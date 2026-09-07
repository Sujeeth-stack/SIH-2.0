# Shared paths for the SANGAM dev stack.
export SANGAM_ROOT=/home/sujeeth_26/sih
export PGDIR=/home/sujeeth_26/pgsql/dist
export PGDATA=/home/sujeeth_26/pgsql/data
export PGRUN=/home/sujeeth_26/pgsql/run
export PGPORT=5433
export PGUSER=sangam
export PGPASSWORD=sangam_dev_pw
export PGDATABASE=sangam
export PGHOST=127.0.0.1
export LD_LIBRARY_PATH="$PGDIR/lib:${LD_LIBRARY_PATH:-}"
export PATH="/home/sujeeth_26/flutter/bin:$PATH"

# Local secrets, if present. Gitignored — this is where RENDER_DATABASE_URL
# lives so a connection string never lands in the repo or in shell history.
if [ -f "$SANGAM_ROOT/sangam_api/.env" ]; then
  set -a
  . "$SANGAM_ROOT/sangam_api/.env"
  set +a
fi
