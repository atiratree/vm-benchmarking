#!/bin/bash

showSettings(){
    if [ -n "$SHOW_SETTINGS" ]; then
        SETTINGS="$1/settings.env"
        if [ -f "$SETTINGS" ]; then
            echo -e "${BLUE}Settings: $SETTINGS${NC}"
            cat "$SETTINGS"
        fi
    fi
}

listBenchmark(){
    BENCHMARK_DIR="$1"
    NAME="`basename "$BENCHMARK_DIR"`"
    showSettings "$BENCHMARK_DIR"
    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        showSettings "$INSTALL_DIR"
        INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"
        if [ -d "$INSTALL_DIR/out" ]; then
            ls -d "$INSTALL_DIR/out"/*
        fi

        VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
        if "$UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
            echo -e "${GREEN}$VM${NC}"
        fi

        for RUN_DIR in "$INSTALL_DIR/"run-v*; do
            if [ ! -d "$RUN_DIR" ]; then
                continue
            fi
            showSettings "$RUN_DIR"

            RUN_VERSION="`basename "$RUN_DIR" | cut -c 6-`"
            VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"

            for RUN_VM in `virsh list --all | grep "$VM""-[0-9+]" |  awk '{print $2}'`; do
                echo -e "${GREEN}$RUN_VM${NC}"
            done

            if [ -d "$RUN_DIR/out" ]; then
                ls -d "$RUN_DIR/out"/*/
            fi

            ANALYSIS_DIR="$RUN_DIR/analysis"
             if [ -d "$ANALYSIS_DIR" ]; then
                ls -d "$ANALYSIS_DIR"/*
            fi
        done
    done
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/config.env"

SHOW_SETTINGS="${SHOW_SETTINGS:-}"

NAME="$1"

if [ -z "$NAME" ]; then
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        if [ -d "$BENCHMARK_DIR" ]; then
            listBenchmark "$BENCHMARK_DIR"
        fi
    done
else
    listBenchmark "$BENCHMARKS_DIR/$NAME"
fi
