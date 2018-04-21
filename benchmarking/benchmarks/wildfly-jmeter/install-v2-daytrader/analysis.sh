#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

function logDetailed(){
	echo "$1"  >> "$DETAILED_ANALYSIS"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
    log "# number of requests to Wildfly"
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

ERR_REGEX="Err:\s*([0-9]*)"
REQUESTS_REGEX="summary =\s*([0-9]*)"
FAILED=""
REQUESTS="0"

SUMMARIES="`grep -e 'summary' "$OUTPUT"`"

while read -r LINE; do
	logDetailed  "$LINE"

    if [[ "$LINE" =~ $ERR_REGEX ]]; then
        ERRORS="${BASH_REMATCH[1]}"
        if [  -n "$ERRORS" ] && [ "$ERRORS"  -gt 0 ]; then
            FAILED="$LINE"
        fi
    fi

    if [[ "$LINE" =~ $REQUESTS_REGEX ]]; then
        REQUESTS="${BASH_REMATCH[1]}"
    fi
done <<< "$SUMMARIES"

if [ -n "$FAILED" ]; then
    log "FAIL: tests were not successful: $FAILED"
    exit 4
fi

log "$REQUESTS"
