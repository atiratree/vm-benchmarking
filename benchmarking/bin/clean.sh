#!/bin/bash

show_help(){
    echo "clean.sh [OPTIONS] [NAME] [INSTALL_VERSION] [RUN_VERSION]"
    echo
    echo "  -a,  --all"
    echo "  -l,  --all-files"
    echo "  --vms"
    echo "  --vms-disk-cache"
    echo "  --analysis"
    echo "  --install"
    echo "  --run"
    echo "  -h, --help"
    echo "  -f, --force    Removes everything without asking"
}

parse_args(){
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
            DELETE_VMS="yes"
            DELETE_VMS_DISK_CACHE="yes"
            DELETE_INSTALL="yes"
            DELETE_RUN=""yes""
            DELETE_ANALYSIS="yes"
            shift
            ;;
            -l|--all-files)
            DELETE_INSTALL="yes"
            DELETE_RUN="yes"
            DELETE_ANALYSIS="yes"
            shift
            ;;
            --vms)
            DELETE_VMS="yes"
            shift
            ;;
            --vms-disk-cache)
            DELETE_VMS_DISK_CACHE="yes"
            shift
            ;;
            --install)
            DELETE_INSTALL="yes"
            shift
            ;;
            --run)
            DELETE_RUN="yes"
            shift
            ;;
            --analysis)
            DELETE_ANALYSIS="yes"
            shift
            ;;
            -f|--force)
            FORCE="yes"
            shift
            ;;
            -h|--help)
            show_help
            exit 0
            ;;
            *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

    NAME="$1"
    INSTALL_VERSION="$2"
    RUN_VERSION="$3"
}

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
        remove_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"
    done
}

remove_run(){
    NAME="$1"
    INSTALL_VERSION="$2"
    RUN_VERSION="$3"

    RUN_DIR="$BENCHMARKS_DIR/$NAME/install-v$INSTALL_VERSION/run-v$RUN_VERSION"

    if [ -n "$DELETE_VMS_DISK_CACHE" ] && [ -d "$IMAGES_CACHE_LOCATION" ]; then
        CACHE_BENCHMARK_VM="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
        CACHED_DISK_FILENAME="`POOL_LOCATION="$IMAGES_CACHE_LOCATION" "$IMAGE_UTIL_DIR"/get-new-disk-filename.sh "$CACHE_BENCHMARK_VM"`"
        if [ -e "$CACHED_DISK_FILENAME" ]; then
            safe_remove "${GREEN}cached image ${RED}$CACHED_DISK_FILENAME${NC}" "$FORCE" \
                &&  verbose_remove "$CACHED_DISK_FILENAME"
        fi
    fi

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
}


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$SCRIPTS_DIR/bench/util"
UTIL_DIR="$SCRIPTS_DIR/util"
source "$UTIL_DIR/common.sh"

parse_args $@

if [ -n "$DELETE_VMS_DISK_CACHE" ] && [ ! -d "$IMAGES_CACHE_LOCATION" ]; then
    echo "IMAGES_CACHE_LOCATION \"$IMAGES_CACHE_LOCATION\" is not a directory" >&2
fi

if [ -n "$RUN_VERSION" ]; then
    remove_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"
elif [ -n "$INSTALL_VERSION" ]; then
    remove_install "$NAME" "$INSTALL_VERSION"
elif [ -n "$NAME" ]; then
    remove_benchmark "$NAME"
else
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        NAME="`basename "$BENCHMARK_DIR"`"
        remove_benchmark "$NAME"
    done
fi
