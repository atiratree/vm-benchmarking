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
ID_RSA="`realpath $SCRIPTS_DIR/../generated/id_rsa`"

"$UTIL_DIR/assert-vm.sh" "$NAME"
exitIfFailed $?

# allow failing
virsh start "$NAME" 2>/dev/null

"$UTIL_DIR/wait-ssh-up.sh" "$NAME" "$ID_RSA"
IP="`"$UTIL_DIR/get-ip.sh" "$NAME" "$ID_RSA"`"

ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i "$ID_RSA" "root@$IP"
