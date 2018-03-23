#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../environment.cfg"
BENCHMARKS_DIR="`realpath $UTIL_DIR/../../../benchmarks`"


NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"

if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 1
fi

if [ -z "$INSTALL_VERSION" ]; then
	echo "install version must be specified" >&2
	exit 2
fi

if [ -z "$RUN_VERSION" ]; then
	echo "run version must be specified" >&2
	exit 3
fi

PART_NAME="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
RUN_DIR="$BENCHMARKS_DIR/$PART_NAME"
exitIfFailed $?

OUT_DIR="$RUN_DIR/out"

LAST_ID="`ls -d "$OUT_DIR"/*/ 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null | grep -o "[0-9]*$"`"

if [ -z "$LAST_ID" ]; then
	ID="000"
else
	ID="$((10#$LAST_ID + 1))"
	ID="$(printf %03d "$ID")"
fi

echo "$ID"
