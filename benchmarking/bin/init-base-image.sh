#!/bin/bash

exitIfFailed(){
	if [ "$1" != 0 ]; then
		exit "$1"
	fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
GENERATED_DIR="$SCRIPTS_DIR/generated"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks`"
source "$SCRIPTS_DIR/config.env"

NAME="$1"

if [ ! -e "$GENERATED_DIR/$SYSTAT_FILENAME" ]; then
    echo "Downloading benchmark scripts dependencies..."
    wget -O "$GENERATED_DIR/$SYSTAT_FILENAME" "https://github.com/sysstat/sysstat/archive/v11.7.2.tar.gz" &> /dev/null
fi

BASE_IMAGE_INSTALL="$BENCHMARKS_DIR/base-image-install.sh"

"$IMAGE_MANAGEMENT_DIR/util/assert-vm.sh" "$NAME"
exitIfFailed $?

if [ ! -e "$BASE_IMAGE_INSTALL" ]; then
	echo "install script must be located at $BASE_IMAGE_INSTALL" >&2
	exit 2
fi

IP="`"$SCRIPTS_DIR/image-management/util/get-ip.sh" "$NAME"`"
exitIfFailed $?

if [ -z "$IP" ]; then
	echo "could not find ip of $1. Is vm running?" >&2
	exit 3
fi

mkdir -p "$GENERATED_DIR"

if [ ! -e "$ID_RSA" ]; then
	ssh-keygen -f "$ID_RSA" -t rsa -b 4096 -N ""
fi

ssh-copy-id -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i "$ID_RSA" "root@$IP"

$SSH "root@$IP" "bash -s" -- < "$BASE_IMAGE_INSTALL"

virsh shutdown "$NAME"
