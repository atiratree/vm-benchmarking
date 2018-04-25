#!/bin/bash

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath $SCRIPTS_DIR/../..`"
BENCHMARKS_DIR="`realpath $BIN_DIR/../benchmarks/`"


RUN_NAME="$1"

set -eu

if [ -z "$RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

remove(){
    if [ -d "$1" ]; then
        echo "rm -rf $1"
        rm -rf "$1"
    fi
}

remove_runs(){
    BENCHMARK_DIR="$1"

    NAME="`basename "$BENCHMARK_DIR"`"

    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        remove "$INSTALL_DIR/run-v$RUN_NAME"
    done
}

for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
    if [ -d "$BENCHMARK_DIR" ]; then
        remove_runs "$BENCHMARK_DIR"
    fi
done
