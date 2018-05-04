#!/bin/bash

set -e

fail_handler(){
    exit "$1"
}

cannot_use_option(){
    if [ -n "$2" ]; then
        echo -e "${RED}skipping $1=$2 for current set of arguments...${NC}" >&2
    fi
}

clone_disk(){
    OLD_DISK_FILENAME="`"$IMAGE_UTIL_DIR"/get-disk-filename.sh "$OLD_NAME"`"
	DISK_FILENAME="`POOL_LOCATION="$POOL_LOCATION" BASE_VM="$OLD_NAME" "$IMAGE_UTIL_DIR"/get-new-disk-filename.sh "$NEW_NAME"`"

	if [ -e "$DISK_FILENAME" ]; then
	    echo "disk already exits" >&2
	    return
	fi

    if [ -z "$SPARSE" -a  "$SPARSE_IMAGES" == "no" ]; then
	    echo "copying full disk ($IMAGE_FORMAT)"
        SPARSE_OPTION="-S 0"
    else
        echo "copying as sparse disk ($IMAGE_FORMAT)"
    fi
    echo "$OLD_DISK_FILENAME -> $DISK_FILENAME"
    qemu-img convert $SPARSE_OPTION -O "$IMAGE_FORMAT" "$OLD_DISK_FILENAME" "$DISK_FILENAME"
}

clone_with_disk(){
    clone --preserve-data  --file "$1"
}

clone(){
    if [ -z "$DISK_ONLY" ]; then
        virt-clone -o "$OLD_NAME" -n "$NEW_NAME" --auto-clone $@
    else
        echo "skipping vm cloning"
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_UTIL_DIR="$SCRIPTS_DIR/util"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"
source "$UTIL_DIR/common.sh"

POOL_LOCATION="${POOL_LOCATION:-}"
SPARSE="${SPARSE:-}"
DISK_ONLY="${DISK_ONLY:-}"

OLD_NAME="$1"
NEW_NAME="$2"
DISK="$3"

if [ -z "$OLD_NAME" -o -z "$NEW_NAME" ]; then
	echo "specify both old and new vm name" >&2
	exit 1
fi

echo -e "${GREEN}$LIBVIRT_DEFAULT_URI: copying $OLD_NAME to $NEW_NAME${NC}"

"$IMAGE_UTIL_DIR/assert-vm.sh" "$OLD_NAME" || fail_handler $?

if [ -n "$DISK" ]; then
    cannot_use_option "POOL_LOCATION" "$POOL_LOCATION"
    cannot_use_option "IMAGE_FORMAT" "$IMAGE_FORMAT"
    cannot_use_option "SPARSE_IMAGES" "$SPARSE_IMAGES"
    cannot_use_option "SPARSE" "$SPARSE"
    clone_with_disk "$DISK"
elif [ -n "$IMAGE_FORMAT" ]; then
    clone_disk
	clone_with_disk "$DISK_FILENAME"
else
    cannot_use_option "POOL_LOCATION" "$POOL_LOCATION"
    cannot_use_option "IMAGE_FORMAT" "$IMAGE_FORMAT"
    cannot_use_option "SPARSE_IMAGES" "$SPARSE_IMAGES"
	# --nonsparse param not working
	# https://ask.fedoraproject.org/en/question/89689/why-does-virt-clone-make-qcow2-images-smaller/
    cannot_use_option "SPARSE" "$SPARSE"
	echo "copying as sparse disk"
	clone
fi
