#!/bin/bash
# Wildlfy Summary at the end also includes building and setup of the tests
# We measure only the test cases without blacklisted tests

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
    log "# TOTAL, BT, CG, DC, EP, FT, IS, LU, MG, SP, UA    (all in sec)"
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

FAILED=""

TIME_REGEX="Time in seconds\s+=\s+([0-9.]+)\s*"
SUCCESS_REGEX="Verification\s+=\s+([^\s]+)\s*"
BENCH_REGEX="([A-Z]{2})\s+Benchmark Completed"

TOTAL=0
PARTIAL_TIMES=""

while read -r LINE; do
	logDetailed  "$LINE"

	if [[ "$LINE" =~ $BENCH_REGEX ]]; then
        NAME="${BASH_REMATCH[1]}"
    fi

    if [[ "$LINE" =~ $TIME_REGEX ]]; then
        SEC="${BASH_REMATCH[1]}"
        TOTAL="`echo "$TOTAL + $SEC" | bc`"
        export "$NAME"="$SEC"
    fi

    if [[ "$LINE" =~ $SUCCESS_REGEX ]]; then
        SUCCESS="${BASH_REMATCH[1]}"
        if [[ "$SUCCESS" =~ "UNSUCCESSFUL" ]]; then
            FAILED="$FAILED $NAME"
        fi
    fi
done <<< "`grep -A 12 -E ".+ Benchmark Completed" "$OUTPUT"`"

if [ -n "$FAILED" ]; then
    log "FAIL: tests were not successful: $FAILED"
    exit 4
fi

log "$TOTAL, $BT, $CG, $DC, $EP, $FT, $IS, $LU, $MG, $SP, $UA"
