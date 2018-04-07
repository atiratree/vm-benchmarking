#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

VERBOSE_FILE="${VERBOSE_FILE:-/dev/null}"

OUTPUT="$1"
ANALYSIS="$2"
DETAILED_ANALYSIS="$3"

if [ ! -f "$OUTPUT" ]; then
	echo "file for analysis must be specified" >&2
	exit 1
fi

if [ ! -f "$ANALYSIS" ]; then
	echo "file for analysis result must be specified" >&2
	exit 2
fi

log "# transactions per second"

TRANSACTION_PER_SECOND=`grep -oe "tps = [0-9.]* (including connections establishing)" "$OUTPUT" | grep -o "[0-9.]*"`

sed '/to the list of known hosts/d; /starting vacuum/d' "$OUTPUT" >> "$DETAILED_ANALYSIS"

log "$TRANSACTION_PER_SECOND"
