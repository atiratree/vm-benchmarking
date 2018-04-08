#!/bin/bash

remove(){
    if [ -d "$1" ]; then
        echo "rm -rf $1"
        rm -rf "$1"
    fi
}

safeRemove(){
    echo -e -n "Are you sure you want to delete $1? (y/n): "
    read -n 1 -r
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo ". skipping..."
        return 1
    fi
    echo
}

removeBenchmark(){
    BENCHMARK_DIR="$1"
    NAME="`basename "$BENCHMARK_DIR"`"
    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"
        if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--install" ]; then
           remove "$INSTALL_DIR/out"
        fi

        if [  "$SELECT" == "--all" -o "$SELECT" == "--vms" ]; then
            VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
            if "$UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
                safeRemove "${GREEN}Vm ${RED}$VM${NC}" && "$IMAGE_MANAGEMENT_DIR"/delete-vm.sh "$VM" > /dev/null 2>&1 && echo "removed $VM"
            fi
        fi

        for RUN_DIR in "$INSTALL_DIR/"run-v*; do
             if [ ! -d "$RUN_DIR" ]; then
                continue
            fi
            RUN_VERSION="`basename "$RUN_DIR" | cut -c 6-`"
            if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--run" ]; then
                remove "$RUN_DIR/out"
            fi
            if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--analysis" ]; then
                ANALYSIS_NAME="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
                ANALYSIS_DIR="$RUN_DIR/analysis"
                 if [ -d "$ANALYSIS_DIR" ]; then
                    safeRemove "${GREEN}Analysis ${RED}$ANALYSIS_NAME${NC}" &&  remove "$ANALYSIS_DIR"
                fi
            fi
        done
    done
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/config.env"

SELECT="$1"
NAME="$2"

if [  "$SELECT" != "--all" -a "$SELECT" != "--analysis" -a "$SELECT" != "--all-files" \
    -a "$SELECT" != "--install" -a "$SELECT" != "--run"  -a "$SELECT" != "--vms" ]; then
    echo "clean.sh OPTION [NAME] "
    echo "  --all"
    echo "  --vms"
    echo "  --all-files"
    echo "  --analysis"
    echo "  --install"
    echo "  --run"
    exit 1
fi

if [ -z "$NAME" ]; then
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        if [ -d "$BENCHMARK_DIR" ]; then
            removeBenchmark "$BENCHMARK_DIR"
        fi
    done
else
    removeBenchmark "$BENCHMARKS_DIR/$NAME/"
fi
