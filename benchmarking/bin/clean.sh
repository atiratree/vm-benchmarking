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

    if [ -n "$DELETE_INSTALL" ]; then
       verbose_remove "$INSTALL_DIR/out"
    fi

    if [ -n "$DELETE_VMS" ]; then
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
        if [ -n "$DELETE_RUN" ]; then
            verbose_remove "$RUN_DIR/out"
        fi

        if [ -n "$DELETE_ANALYSIS" ]; then
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

FORCE="${FORCE:-}"
POSITIONAL_ARGS=()

for ARG in $@; do
    case $ARG in
        --all)
        DELETE_VMS="$ARG"
        DELETE_VMS_DISK_CACHE="$ARG"
        DELETE_INSTALL="$ARG"
        DELETE_RUN="$ARG"
        DELETE_ANALYSIS="$ARG"
        shift
        ;;
        --all-files)
        DELETE_INSTALL="$ARG"
        DELETE_RUN="$ARG"
        DELETE_ANALYSIS="$ARG"
        shift
        ;;
        --vms)
        DELETE_VMS="$ARG"
        shift
        ;;
        --install)
        DELETE_INSTALL="$ARG"
        shift
        ;;
        --run)
        DELETE_RUN="$ARG"
        shift
        ;;
        --analysis)
        DELETE_ANALYSIS="$ARG"
        shift
        ;;
        *)
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

NAME="$1"
INSTALL_VERSION="$2"

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
