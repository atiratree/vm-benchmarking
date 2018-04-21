#!/bin/bash

exitIfFailed(){
	if [ $1 -ne 0 ]; then	
	    echo "exiting unexpectedly: cleaning up"
		if [ -e "$RESULT" ]; then
			echo "failed with return code $1" >> "$RESULT"
		fi
		"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$FULL_NAME"
        exit $?
    fi
}

safeRemove(){
    echo -e -n "Are you sure you want to delete $1? (y/n): "
    read -n 1 -r
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo ". preparations skipped..."
        exit 0
    fi
    echo
}

copyToRemote(){
    IP="$1"
    DIR_TO_COPY="$2"

    if [ -d "$DIR_TO_COPY" ]; then
        $SCP -r "$DIR_TO_COPY"  "root@$IP:/tmp/" &> /dev/null
    fi
}


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath $SCRIPTS_DIR/../image-management`"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/../config.env"

BASE_VM="$1"
NAME="$2"
INSTALL_VERSION="$3"

if [ -z "$BASE_VM" ]; then
	echo "base vm must be specified" >&2
	exit 1
fi

if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 2
fi

if [ -z "$INSTALL_VERSION" ]; then
	echo "install version must be specified" >&2
	exit 3
fi

BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../../benchmarks/`"
BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

INSTALL_DIR_PART="`DIR=TRUE "$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
VERSIONED_INSTALL_DIR="$BENCHMARKS_DIR/$INSTALL_DIR_PART"

INSTALL_SCRIPT="$BENCHMARK_DIR/install.sh"
VERSIONED_INSTALL_SCRIPT="$VERSIONED_INSTALL_DIR/install.sh"

RESULTS_DIR="$VERSIONED_INSTALL_DIR/out"
RESULT="$RESULTS_DIR/output"

if [ ! -e "$INSTALL_SCRIPT" ]; then
	echo "install script $INSTALL_SCRIPT must be specified" >&2
	exit 4
fi

"$IMAGE_UTIL_DIR/assert-vm.sh" "$BASE_VM"
exitIfFailed $?

FULL_NAME="`"$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

if virsh list --all | awk  '{print $2}' | grep -q --line-regexp --fixed-strings "$FULL_NAME"; then
	echo "$LIBVIRT_DEFAULT_URI: vm is present. Removing..."
	safeRemove "${GREEN}Vm ${RED}$FULL_NAME${NC}"
	"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$FULL_NAME"
fi

if [ -d "$RESULTS_DIR" ]; then
	echo "removing $RESULTS_DIR"
	rm -rf "$RESULTS_DIR"
fi

mkdir -p "$RESULTS_DIR"
> "$RESULT"

echo -e "${BLUE}preparing $FULL_NAME${NC}"
"$IMAGE_MANAGEMENT_DIR/clone-vm.sh" "$BASE_VM" "$FULL_NAME"
exitIfFailed $?

virsh start "$FULL_NAME"
exitIfFailed $?


"$IMAGE_UTIL_DIR/wait-ssh-up.sh" "$FULL_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Could not connect to the vm!${NC}"
    exit 5
fi

IP="`"$IMAGE_UTIL_DIR/get-ip.sh" "$FULL_NAME"`"

# install
if [ -e "$VERSIONED_INSTALL_SCRIPT" ]; then
    echo -e "${GREEN}Installing with addon: $VERSIONED_INSTALL_SCRIPT${NC}"
else
    echo -e "${GREEN}Installing${NC}"
fi

$SSH "root@$IP" "echo $FULL_NAME > /etc/hostname" &> /dev/null

copyToRemote "$IP" "$BENCHMARK_DIR/dependencies"
copyToRemote "$IP" "$VERSIONED_INSTALL_DIR/dependencies"

FINAL_SCRIPT="`SCRIPT_FILE="$INSTALL_SCRIPT" POST_SCRIPT_FILE="$VERSIONED_INSTALL_SCRIPT" "$IMAGE_UTIL_DIR/get-settings.sh" "$NAME" "$INSTALL_VERSION"`"
$SSH "root@$IP" "bash -s" -- <<< "$FINAL_SCRIPT" 2>&1 | tee "$VERBOSE_FILE" >> "$RESULT"
exitIfFailed $?

$SSH "root@$IP" "rm -rf /tmp/dependencies" 2>&1 | tee "$VERBOSE_FILE" >> "$RESULT"

# "$IMAGE_MANAGEMENT_DIR/vm-up.sh" "$NAME"
virsh shutdown "$FULL_NAME"

echo -e "${BLUE}Install output can be found in `realpath $RESULTS_DIR`${NC}"

