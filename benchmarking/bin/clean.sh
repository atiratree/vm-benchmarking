#!/bin/bash

remove_benchmark(){
    NAME="$1"
    BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

    if [ ! -d "$BENCHMARK_DIR" ]; then
        return
    fi

    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"
        remove_install "$NAME" "$INSTALL_VERSION"
    done
}

remove_install(){
    NAME="$1"
    INSTALL_VERSION="$2"

    INSTALL_DIR="$BENCHMARKS_DIR/$NAME/install-v$INSTALL_VERSION"

    if [ ! -d "$INSTALL_DIR" ]; then
        return
    fi

    if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--install" ]; then
       verbose_remove "$INSTALL_DIR/out"
    fi

    if [  "$SELECT" == "--all" -o "$SELECT" == "--vms" ]; then
        VM="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
        if "$IMAGE_UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
            safe_remove "${GREEN}Vm ${RED}$VM${NC}" "$FORCE" && "$IMAGE_MANAGEMENT_DIR"/delete-vm.sh "$VM" > /dev/null 2>&1 && echo "removed $VM"
        fi
    fi

    for RUN_DIR in "$INSTALL_DIR/"run-v*; do
         if [ ! -d "$RUN_DIR" ]; then
            continue
        fi
        RUN_VERSION="`basename "$RUN_DIR" | cut -c 6-`"
        if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--run" ]; then
            verbose_remove "$RUN_DIR/out"
        fi
        if [  "$SELECT" == "--all" -o "$SELECT" == "--all-files" -o "$SELECT" == "--analysis" ]; then
            ANALYSIS_NAME="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
            ANALYSIS_DIR="$RUN_DIR/analysis"
             if [ -d "$ANALYSIS_DIR" ]; then
                safe_remove "${GREEN}Analysis ${RED}$ANALYSIS_NAME${NC}" "$FORCE" &&  verbose_remove "$ANALYSIS_DIR"
            fi
        fi
    done
}


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$SCRIPTS_DIR/bench/util"
UTIL_DIR="$SCRIPTS_DIR/util"
source "$UTIL_DIR/common.sh"
source "$SCRIPTS_DIR/config.env"

FORCE="${FORCE:-}"

SELECT="$1"
NAME="$2"
INSTALL_VERSION="$3"

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

if [ -n "$INSTALL_VERSION" ]; then
    remove_install "$NAME" "$INSTALL_VERSION"
elif [ -n "$NAME" ]; then
    remove_benchmark "$NAME"
else
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        NAME="`basename "$BENCHMARK_DIR"`"
        remove_benchmark "$NAME"
    done
fi
