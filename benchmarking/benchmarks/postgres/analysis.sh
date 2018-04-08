#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

VERBOSE_FILE="${VERBOSE_FILE:-/dev/null}"
PRINT_HEADER="${PRINT_HEADER:-}"

ANALYSIS="$1"
DETAILED_ANALYSIS="$2"
OUTPUT="$3"

if [ ! -f "$ANALYSIS" ]; then
	echo "file for analysis result must be specified" >&2
	exit 1
fi

if [ -n "$PRINT_HEADER" ]; then
    log "# transactions per second"
    exit 0
fi

if [ ! -f "$DETAILED_ANALYSIS" ]; then
	echo "file for detailed analysis result must be specified" >&2
	exit 2
fi

if [ ! -f "$OUTPUT" ]; then
	echo "file for analysis must be specified" >&2
	exit 3
fi


TRANSACTION_PER_SECOND=`grep -oe "tps = [0-9.]* (including connections establishing)" "$OUTPUT" | grep -o "[0-9.]*"`

sed '/to the list of known hosts/d; /starting vacuum/d' "$OUTPUT" >> "$DETAILED_ANALYSIS"

log "$TRANSACTION_PER_SECOND"
