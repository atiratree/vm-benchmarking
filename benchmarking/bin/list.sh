#!/bin/bash

help(){
    echo "list.sh [OPTIONS] [NAME]"
    echo
    echo "  -s, --show-settings"
    echo "  -h, --help"
}

show_settings(){
    if [ -n "$SHOW_SETTINGS" ]; then
        SETTINGS="$1/settings.env"
        if [ -f "$SETTINGS" ]; then
            echo -e "${BLUE}Settings: $SETTINGS${NC}"
            cat "$SETTINGS"
        fi
    fi
}

list_benchmark(){
    BENCHMARK_DIR="$1"
    NAME="`basename "$BENCHMARK_DIR"`"
    show_settings "$BENCHMARK_DIR"
    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"

        VM="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
        if "$IMAGE_UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
            echo -e "${GREEN}$VM${NC}"
        fi

        show_settings "$INSTALL_DIR"
        if [ -d "$INSTALL_DIR/out" ]; then
            ls -d "$INSTALL_DIR/out"/*
        fi

        for RUN_DIR in "$INSTALL_DIR/"run-v*; do
            if [ ! -d "$RUN_DIR" ]; then
                continue
            fi
            show_settings "$RUN_DIR"

            RUN_VERSION="`basename "$RUN_DIR" | cut -c 6-`"
            VM="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"

            for RUN_VM in `virsh list --all 2> /dev/null | grep "$VM""-[0-9+]" |  awk '{print $2}'`; do
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
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$SCRIPTS_DIR/bench/util"
UTIL_DIR="$SCRIPTS_DIR/util"

source "$UTIL_DIR/common.sh"

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--show-settings)
        SHOW_SETTINGS="YES"
        shift
        ;;
        -h|--help)
        help
        exit 0
        ;;
        *)
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

NAME="$1"

if [ -z "$NAME" ]; then
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        if [ -d "$BENCHMARK_DIR" ]; then
            list_benchmark "$BENCHMARK_DIR"
        fi
    done
else
    list_benchmark "$BENCHMARKS_DIR/$NAME"
fi
