#!/bin/bash

BENCH_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$BENCH_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"
source "$BENCH_UTIL_DIR/../../config.env"
BENCHMARKS_DIR="`realpath "$BENCH_UTIL_DIR/../../../benchmarks"`"

NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"

assert_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"

PART_NAME="`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
RUN_DIR="$BENCHMARKS_DIR/$PART_NAME"

OUT_DIR="$RUN_DIR/out"

LAST_ID="`ls -d "$OUT_DIR"/*/ 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null | grep -o "[0-9]*$"`"

if [ -z "$LAST_ID" ]; then
	ID="000"
else
	ID="$((10#$LAST_ID + 1))"
	ID="$(printf %03d "$ID")"
fi

echo "$ID"
