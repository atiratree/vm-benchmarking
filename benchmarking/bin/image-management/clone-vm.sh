#!/bin/bash

set -e

fail_handler(){
    exit "$1"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_UTIL_DIR="$SCRIPTS_DIR/util"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"
source "$UTIL_DIR/common.sh"

POOL_LOCATION="${POOL_LOCATION:-}"

OLD_NAME="$1"
NEW_NAME="$2"
SPARSE="$3"

if [ -z "$OLD_NAME" -o -z "$NEW_NAME" ]; then
	echo "specify both old and new name" >&2
	exit 1
fi

echo -e "${GREEN}$LIBVIRT_DEFAULT_URI: copying $OLD_NAME to $NEW_NAME${NC}"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$OLD_NAME" || fail_handler $?
if [ -n "$IMAGE_FORMAT" ]; then
	OLD_DISK_FILENAME="`"$IMAGE_UTIL_DIR"/get-disk-filename.sh "$OLD_NAME"`"
	DISK_FILENAME="`POOL_LOCATION="$POOL_LOCATION" BASE_VM="$OLD_NAME" "$IMAGE_UTIL_DIR"/get-new-disk-filename.sh "$NEW_NAME"`"

    if [ -z "$SPARSE" -a  "$SPARSE_IMAGES" == "no" ]; then
	    echo "copying full disk ($IMAGE_FORMAT)"
        SPARSE_OPTION="-S 0"
    else
        echo "copying as sparse disk ($IMAGE_FORMAT)"
    fi
    echo "$OLD_DISK_FILENAME -> $DISK_FILENAME"
    qemu-img convert $SPARSE_OPTION -O "$IMAGE_FORMAT" "$OLD_DISK_FILENAME" "$DISK_FILENAME"

	virt-clone --preserve-data -o "$OLD_NAME" -n "$NEW_NAME" --auto-clone  --preserve-data  --file "$DISK_FILENAME"
else
	# --nonsparse param not working
	# https://ask.fedoraproject.org/en/question/89689/why-does-virt-clone-make-qcow2-images-smaller/
	echo "copying as sparse disk"
	virt-clone -o "$OLD_NAME" -n "$NEW_NAME" --auto-clone
fi
