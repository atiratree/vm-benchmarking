#!/bin/bash

fail_handler(){
    exit "$1"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCH_UTIL_DIR="`realpath "$SCRIPTS_DIR/../bench/util"`"
IMAGE_UTIL_DIR="$SCRIPTS_DIR/util"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"
GET_NAME="$BENCH_UTIL_DIR/get-name.sh"
source "$UTIL_DIR/common.sh"

FORWARD_FROM="${FORWARD_FROM:-}"
FORWARD_TO="${FORWARD_TO:-8080}"

if [ -f "$GET_NAME" ]; then
    NAME="`"$GET_NAME" "$@"`"
else
    NAME="$1"
fi

"$IMAGE_UTIL_DIR/assert-vm.sh" "$NAME" || fail_handler $?

# allow failing
virsh start "$NAME" 2>/dev/null

"$IMAGE_UTIL_DIR/wait-ssh-up.sh" "$NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Could not connect to the vm!${NC}"
    exit 1
fi

IP="`"$IMAGE_UTIL_DIR/get-ip.sh" "$NAME"`"

if [ -z "$FORWARD_FROM" ] || [ -z "$FORWARD_TO" ]; then
    $SSH "root@$IP"
else
    echo -e "${GREEN}forwarding: $IP:$FORWARD_FROM -> localhost:$FORWARD_TO${NC}"
    $SSH -N -L "$FORWARD_TO:localhost:$FORWARD_FROM" "root@$IP"
fi
