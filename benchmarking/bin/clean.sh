#!/bin/bash

remove(){
    if [ -d "$1" ]; then
        echo "rm -rf $1"
        rm -rf "$1"
    fi
}

removeBenchmark(){
    BENCHMARK_DIR="$1"
    for INSTALL_DIR in `ls -d "$BENCHMARK_DIR"install-v*/`; do
        if [  "$SELECT" == "--all" -o "$SELECT" == "--install" ]; then
           remove "$INSTALL_DIR""out"
        fi
        if [  "$SELECT" == "--all" -o "$SELECT" == "--run" ]; then
            for RUN_DIR in `ls -d "$INSTALL_DIR"run-v*/`; do
                remove "$RUN_DIR""out"
            done
        fi
    done
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"

SELECT="$1"
NAME="$2"

if [  "$SELECT" != "--all" -a "$SELECT" != "--install" -a "$SELECT" != "--run"  ]; then
    echo "clean.sh OPTION [NAME] "
    echo "  --install"
    echo "  --run"
    echo "  --all"
    exit 1
fi

if [ -z "$NAME" ]; then
    for BENCHMARK_DIR in `ls -d "$BENCHMARKS_DIR"/*/`; do
        removeBenchmark "$BENCHMARK_DIR"
    done
else
    removeBenchmark "$BENCHMARKS_DIR/$NAME/"
fi
