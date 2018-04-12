#!/bin/bash

set -eu

CLIENTS="`echo "$THREADS * 2" | bc`" # clients running simultaneously

# run benchmark
sudo -i -u postgres /usr/pgsql-10/bin/pgbench --jobs="$THREADS" --client="$CLIENTS"  "$NAME" --time="$RUN_TIME"
