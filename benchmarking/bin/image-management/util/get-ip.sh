#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"

NAME="$1"

"$UTIL_DIR/assert-vm.sh" "$NAME"
exitIfFailed $?

XML="`virsh dumpxml "$NAME"`"

MAC_ADDRESS="`echo "$XML" | sed -n "s/.*mac address='\([^']*\)'.*/\1/p"`"
NETWORK="`echo "$XML" | sed -n "s/.*source network='\([^']*\)'.*/\1/p"`"

virsh net-dhcp-leases "$NETWORK" --mac "$MAC_ADDRESS" \
| awk '{ print $5; }'\
| grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'
	
exit 0
