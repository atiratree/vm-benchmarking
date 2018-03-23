#!/bin/bash

set -e

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

OLD_NAME="$1"
NEW_NAME="$2"
SPARSE="$3"

if [ -z "$OLD_NAME" -o -z "$NEW_NAME" ]; then
	echo "specify both old and new name" >&2
	exit 1
fi

echo -e "${GREEN}$LIBVIRT_DEFAULT_URI: copying $OLD_NAME to $NEW_NAME${NC}"

"$UTIL_DIR/assert-vm.sh" "$OLD_NAME"
exitIfFailed $?

if [ -z "$SPARSE" ]; then
	# --nonsparse param not working
	# https://ask.fedoraproject.org/en/question/89689/why-does-virt-clone-make-qcow2-images-smaller/
	echo "copying full disk"
	OLD_DISK_FILENAME="`virsh dumpxml "$OLD_NAME" | grep "/.*/*$OLD_NAME.qcow2" -o`"
	DISK_FILENAME="`echo "$OLD_DISK_FILENAME"  | sed  "s/$OLD_NAME/$NEW_NAME/"`"

	virsh vol-clone --prealloc-metadata "$OLD_DISK_FILENAME"  "$NEW_NAME".qcow2

	virt-clone --preserve-data -o "$OLD_NAME" -n "$NEW_NAME" --auto-clone  --preserve-data  --file "$DISK_FILENAME"
else
	echo "copying as sparse disk"
	virt-clone -o "$OLD_NAME" -n "$NEW_NAME" --auto-clone
fi

exit 0
