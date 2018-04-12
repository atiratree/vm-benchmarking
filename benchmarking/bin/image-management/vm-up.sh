#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="$SCRIPTS_DIR/util"
source "$SCRIPTS_DIR/../config.env"


NAME="`"$UTIL_DIR/get-name.sh" "$@"`"

"$UTIL_DIR/assert-vm.sh" "$NAME"
exitIfFailed $?

# allow failing
virsh start "$NAME" 2>/dev/null

"$UTIL_DIR/wait-ssh-up.sh" "$NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Could not connect to the vm!${NC}"
    exit 1
fi

IP="`"$UTIL_DIR/get-ip.sh" "$NAME"`"

$SSH "root@$IP"
