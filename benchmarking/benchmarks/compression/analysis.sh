#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

function logDetailed(){
	echo "$1"  >> "$DETAILED_ANALYSIS"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VERBOSE_FILE="${VERBOSE_FILE:-/dev/null}"

OUTPUT="$1"
ANALYSIS="$2"
DETAILED_ANALYSIS="$3"
SHOW_HEADER="$4"

if [ ! -f "$OUTPUT" ]; then
	echo "file for analysis must be specified" >&2
	exit 1
fi

if [ ! -f "$ANALYSIS" ]; then
	echo "file for analysis result must be specified" >&2
	exit 2
fi

if [ -n "$SHOW_HEADER" ]; then
    log "# time elapsed (in seconds)"
fi

REGEX="real\s+([0-9.]+)"

TIME=0

CONTENT="`sed '/to the list of known hosts/d; /starting vacuum/d' "$OUTPUT"`"

while read -r LINE; do
    if [ -n "$LINE" ]; then
        logDetailed  "$LINE"
        if [[ "$LINE" =~ "done" ]]; then
            FINISHED="TRUE"
        fi
    fi

    if [[ "$LINE" =~ $REGEX ]]; then
        SEC="${BASH_REMATCH[1]}"
        TIME="`echo "$TIME + $SEC" | bc`"
    fi
done <<< "$CONTENT"

if [ -z "$FINISHED" ]; then
    log "FAIL: tests were not successful"
    exit 3
fi

log "$TIME"
