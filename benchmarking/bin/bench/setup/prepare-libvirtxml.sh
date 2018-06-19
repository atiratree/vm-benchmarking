#!/bin/bash

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath "$SCRIPTS_DIR/../.."`"
BENCHMARKS_DIR="`realpath "$BIN_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$BIN_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$BIN_DIR/bench/util"
UTIL_DIR="$BIN_DIR/util"
source "$UTIL_DIR/common.sh"

RUN_NAME="$1"
FINISH="$2"

set -eu

if [ -z "$RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

LAST_XML_WC=""
LIBVIRT_XML_RESULT="$GENERATED_DIR/libvirt.xml.$RUN_NAME"
LIBVIRT_XML_RESULT_PREPARING="$GENERATED_DIR/libvirt.xml.$RUN_NAME.preparing"
LIBVIRT_XML_RESULT_PATCH="$GENERATED_DIR/libvirt.xml.$RUN_NAME.patch"


supports_xml(){
    echo "$1" | grep -qvf "$SCRIPTS_DIR/.run_libvirtxml_ignore"
}

fetch_libvirtxml(){
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
            echo -e "${RED}skipping $VM ... does not exist${NC}"
            continue
        fi

        XML="`virsh dumpxml "$VM" `"
        XML_WC="`echo "$XML" | wc -l`"

        if [ -z "$LAST_XML_WC" ]; then
            echo "$XML" > "$LIBVIRT_XML_RESULT"
            echo "$XML" > "$LIBVIRT_XML_RESULT_PREPARING"
            LIBVIRT_XML_EXAMPLE="$INSTALL_DIR/run-v$RUN_NAME/libvirt.xml.example"
        else
            if [ "$XML_WC" -ne "$LAST_XML_WC" ]; then
                echo -e "${RED}word count of $VM xml differs (may not work)${NC}"
            fi
        fi
        LAST_XML_WC="$XML_WC"
    done
}

finish_libvirtxml(){
    diff -U 0 "$LIBVIRT_XML_RESULT_PREPARING" "$LIBVIRT_XML_RESULT" > "$LIBVIRT_XML_RESULT_PATCH" || :
    echo "patch created: $LIBVIRT_XML_RESULT_PATCH"
    rm -rf "$LIBVIRT_XML_RESULT_PREPARING" "$LIBVIRT_XML_RESULT"
}

if [ "$FINISH" != "--finish" ]; then
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        if [ -d "$BENCHMARK_DIR" ]; then
            fetch_libvirtxml "$BENCHMARK_DIR"
        fi
    done

    echo
    echo "1. edit $LIBVIRT_XML_RESULT"
    echo "2. merge with current libvirt.xml.example bellow"
    echo -e "3. run ${GREEN} \"$SCRIPTS_DIR/prepare-libvirtxml.sh $RUN_NAME --finish\"${NC}"
    echo

    if [ -f "$LIBVIRT_XML_EXAMPLE" ]; then
        echo -e "${BLUE}current libvirt.xml.example: ${NC}"
        echo
        cat "$LIBVIRT_XML_EXAMPLE"
    fi
else
    if [ ! -f "$LIBVIRT_XML_RESULT" ]; then
        echo "cannot continue: $LIBVIRT_XML_RESULT does not exist"
        exit 1
    fi
    if  [ ! -f "$LIBVIRT_XML_RESULT_PREPARING" ]; then
        echo "cannot continue: $LIBVIRT_XML_RESULT_PREPARING does not exist"
        exit 2
    fi

    finish_libvirtxml
    "$SCRIPTS_DIR"/util/patch-run-libvirtxmls.sh "$RUN_NAME"
fi



