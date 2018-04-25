#!/bin/bash


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath $SCRIPTS_DIR/../..`"
BENCHMARKS_DIR="`realpath $BIN_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$BIN_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$BIN_DIR/config.env"


RUN_NAME="$1"

set -eu

if [ -z "$RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

LIBVIRT_XML_RESULT_PATCH="$GENERATED_DIR/libvirt.xml.$RUN_NAME.patch"


supports_xml(){
    echo "$1" | grep -qvf "$SCRIPTS_DIR/.run_libvirtxml_ignore"
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

        VM="`"$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

        if ! "$IMAGE_UTIL_DIR/"assert-vm.sh "$VM" 2> /dev/null; then
            echo -e "${RED}skipping $VM ... does not exit${NC}"
            continue
        fi

        RUN_DIR="$INSTALL_DIR/run-v$RUN_NAME"
        LIBVIRT_XML="$RUN_DIR/libvirt.xml"

        mkdir -p "$RUN_DIR"
        virsh dumpxml "$VM" > "$LIBVIRT_XML"
        patch  "$LIBVIRT_XML" "$LIBVIRT_XML_RESULT_PATCH"
    done
}


for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
    if [ -d "$BENCHMARK_DIR" ]; then
        fetch_libvirtxmls "$BENCHMARK_DIR"
    fi
done
