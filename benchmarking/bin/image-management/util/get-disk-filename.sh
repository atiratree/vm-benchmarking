#!/bin/bash

set -e
IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$IMAGE_UTIL_DIR/../../config.env"

VM="$1"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$VM"

virsh dumpxml "$VM" | grep "/.*/*$VM.qcow2" -o | head -1
