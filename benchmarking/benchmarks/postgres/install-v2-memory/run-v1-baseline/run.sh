#!/bin/bash

set -e

if [ -z "$PROCESSORS" ] || [ -z "$RUN_TIME" ]; then
	echo "Failed" 2>&1
	exit 1
fi

CLIENTS="`echo "$PROCESSORS * 2" | bc`" # clients running simultaneously


# run benchmark
sudo -i -u postgres /usr/pgsql-10/bin/pgbench --jobs="$PROCESSORS" --client="$CLIENTS"  "$NAME" --time="$RUN_TIME"
