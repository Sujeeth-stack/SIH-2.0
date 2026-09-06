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
