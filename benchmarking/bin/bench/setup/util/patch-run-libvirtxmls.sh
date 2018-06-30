#!/bin/bash

show_help(){
    echo "patch-run-libvirtxml.sh RUN_NAME "
    echo
    echo "  -h, --help"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath "$SCRIPTS_DIR/../../.."`"
SETUP_DIR="`realpath "$SCRIPTS_DIR/.."`"
BENCHMARKS_DIR="`realpath "$BIN_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$BIN_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$BIN_DIR/bench/util"
UTIL_DIR="$BIN_DIR/util"
source "$UTIL_DIR/common.sh"

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
        show_help
        exit 0
        ;;
        *)
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

RUN_NAME="$1"

set -eu

if [ -z "$RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

LIBVIRT_XML_RESULT_PATCH="$GENERATED_DIR/libvirt.xml.$RUN_NAME.patch"


if [ ! -f "$LIBVIRT_XML_RESULT_PATCH" ]; then
    echo "cannot continue: $LIBVIRT_XML_RESULT_PATCH does not exist"
    exit 2
fi

supports_xml(){
    echo "$1" | grep -qvf "$SETUP_DIR/.run_libvirtxml_ignore"
}

fetch_libvirtxmls(){
    BENCHMARK_DIR="$1"

    NAME="`basename "$BENCHMARK_DIR"`"
    if ! supports_xml "$NAME"; then
        return
    fi
    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"

        VM="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

        if ! "$IMAGE_UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
            echo -e "skipping $VM ... ${RED}VM does not exit${NC}"
            continue
        fi

        RUN_DIR="$INSTALL_DIR/run-v$RUN_NAME"
        LIBVIRT_XML="$RUN_DIR/libvirt.xml"

        if [ -d "$RUN_DIR" ]; then
            virsh dumpxml "$VM" > "$LIBVIRT_XML"
            patch  "$LIBVIRT_XML" "$LIBVIRT_XML_RESULT_PATCH"
        else
             echo -e "skipping $VM ... ${RED}RUN does not exit${NC}"
        fi
    done
}


for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
    if [ -d "$BENCHMARK_DIR" ]; then
        fetch_libvirtxmls "$BENCHMARK_DIR"
    fi
done
