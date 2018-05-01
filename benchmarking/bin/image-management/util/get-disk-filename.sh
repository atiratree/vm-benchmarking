#!/bin/bash

set -e
IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$IMAGE_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"

VM="$1"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$VM"

virsh dumpxml "$VM" | grep  -Eo "/.*/*$VM.[a-zA-Z0-9]+" | head -1
