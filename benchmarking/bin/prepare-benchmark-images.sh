#!/bin/bash

exitIfFailed(){
	if [ $1 -ne 0 ]; then
	    echo "preparing $NAME $INSTALL_VERSION from $BASE_IMAGE failed"
	    echo "stopping other preparations..."
        exit $?
    fi
}

prepare-vm(){
	BASE_IMAGE="$1"
    NAME="$2"
    INSTALL_VERSION="$3"

    if [ -z "$BASE_IMAGE" ] || [ -z "$INSTALL_VERSION" ] || [ ${BASE_IMAGE:0:1} == "#" ]; then
        return 0
    fi
    "$IMAGE_MANAGEMENT_DIR/prepare-vm.sh" "$BASE_IMAGE" "$NAME" "$INSTALL_VERSION"
    exitIfFailed $?
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"

source "$SCRIPTS_DIR/config.env"
SUITE="$BENCHMARKS_DIR/benchmark-images.cfg"

if [  "$1" == "-v" ]; then
	export VERBOSE_FILE=/dev/tty
fi

if [ ! -e "$SUITE" ]; then
	echo "$SUITE must be specified" >&2
	exit 1
fi

lines=`cat "$SUITE" | wc -l`
for i in `seq 1 $lines`
    do
    variable="'$i""q;d' $SUITE"
    prepare-vm `eval sed "$variable"`
done
