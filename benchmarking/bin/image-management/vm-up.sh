#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_UTIL_DIR="$SCRIPTS_DIR/util"
source "$SCRIPTS_DIR/../config.env"

FORWARD_FROM="${FORWARD_FROM:-}"
FORWARD_TO="${FORWARD_TO:-8080}"
NAME="`"$IMAGE_UTIL_DIR/get-name.sh" "$@"`"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$NAME"
exitIfFailed $?

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
