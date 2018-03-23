#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="$SCRIPTS_DIR/util"
source "$SCRIPTS_DIR/../environment.cfg"

NAME="$1"

echo -e "${GREEN}$LIBVIRT_DEFAULT_URI: deleting $NAME${NC}"

"$UTIL_DIR/assert-vm.sh" "$NAME"
exitIfFailed $?

DISK_FILENAME="`virsh dumpxml "$NAME" | grep "/.*/*$NAME.qcow2" -o`"

virsh destroy "$NAME" 2> /dev/null
virsh undefine "$NAME" && virsh vol-delete "$DISK_FILENAME"
