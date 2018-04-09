#!/bin/bash

# Memory Cached  Test

set -eu

SCALE="`echo "$RAM * 75 * $SCALE_MULTIPLIER_CONSTANT" | bc | xargs printf "%.0f"`"
echo "Buffer Install: using scale $SCALE for ram $RAM GiB"

# prepare db
sudo -i -u postgres createdb "$NAME"

# prepare test tables
sudo -i -u postgres /usr/pgsql-10/bin/pgbench --initialize --scale="$SCALE" --foreign-keys "$NAME"
