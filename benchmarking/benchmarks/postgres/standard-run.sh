#!/bin/bash

set -eu

CLIENTS="`echo "$THREADS * 2" | bc`" # clients running simultaneously

# wait for start
systemctl start postgresql-10 || exit -1

# run benchmark
sudo -i -u postgres /usr/pgsql-10/bin/pgbench --jobs="$THREADS" --client="$CLIENTS"  "$NAME" --time="$RUN_TIME"
