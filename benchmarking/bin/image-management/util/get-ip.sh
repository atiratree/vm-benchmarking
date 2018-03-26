#!/bin/bash

exit_if_failed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

validate_ip(){
    RESULT="`echo "$1" | grep -o "$IP_4_REGEX"`"
    if [ -n "$RESULT" ]; then
        echo "$RESULT"
        exit 0
    fi
}

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"

NAME="$1"

"$UTIL_DIR/assert-vm.sh" "$NAME"
exit_if_failed $?

validate_ip "$STATIC_IP"

XML="`virsh dumpxml "$NAME"`"

MAC_ADDRESS="`echo "$XML" | sed -n "s/.*mac address='\([^']*\)'.*/\1/p"`"
NETWORK="`echo "$XML" | sed -n "s/.*source network='\([^']*\)'.*/\1/p"`"

if [ -z "$NETWORK" ]; then
    INTERFACE="`echo "$XML" | sed -n "s/.*source bridge='\([^']*\)'.*/\1/p"`"
    INTERFACE_SUBNET="`ip -f inet  addr show "$INTERFACE" | grep -Po 'inet \K[\d./]+'`"

    validate_ip "`ip neighbour show "$INTERFACE_SUBNET" | grep "$MAC_ADDRESS" | cut -f1 -d' '`"
    # ping neighbours if not found
    validate_ip "`nmap -n -sP "$INTERFACE_SUBNET" | grep -B 2  --ignore-case "$MAC_ADDRESS" | head -1`"
else
    validate_ip "`virsh net-dhcp-leases "$NETWORK" --mac "$MAC_ADDRESS" | awk '{ print $5; }'`"
fi

exit 0
