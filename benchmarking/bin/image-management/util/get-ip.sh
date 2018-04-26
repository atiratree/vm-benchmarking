#!/bin/bash

fail_handler(){
    exit "$1"
}

validate_ip(){
    RESULT="`echo "$1" | grep -o "$IP_4_REGEX"`"
    if [ -n "$RESULT" ]; then
        echo "$RESULT"
        exit 0
    fi
}

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$IMAGE_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"
source "$IMAGE_UTIL_DIR/../../config.env"

NAME="$1"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$NAME" || fail_handler $?

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
