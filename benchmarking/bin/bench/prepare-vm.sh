#!/bin/bash

fail_handler(){
    echo "exiting unexpectedly: cleaning up"
    if [ -e "$RESULT" ]; then
        echo "failed with return code $1" >> "$RESULT"
    fi
    "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$FULL_NAME"
    exit $1
}

safe_remove(){
    echo -e -n "Are you sure you want to delete $1? (y/n): "
    if [ -z "$FORCE" ]; then
        read -n 1 -r
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo ". preparations skipped..."
            exit 0
        fi
    else
         echo -e -n "y (forced)"
    fi
    echo
}

copy_to_remote(){
    IP="$1"
    DIR_TO_COPY="$2"

    if [ -d "$DIR_TO_COPY" ]; then
        $SCP -r "$DIR_TO_COPY"  "root@$IP:/tmp/" &> /dev/null
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath $SCRIPTS_DIR/../image-management`"
UTIL_DIR="`realpath $SCRIPTS_DIR/../util`"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/../config.env"
source "$UTIL_DIR/common.sh"

FORCE="${FORCE:-}"

BASE_VM="$1"
NAME="$2"
INSTALL_VERSION="$3"

assert_install "$NAME" "$INSTALL_VERSION"

if [ -z "$BASE_VM" ]; then
	echo "base vm must be specified" >&2
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
RESULT_SETTINGS="$RESULTS_DIR/settings.env"
RESULT_RELEASE="$RESULTS_DIR/release"

if [ ! -e "$INSTALL_SCRIPT" ]; then
	echo "install script $INSTALL_SCRIPT must be specified" >&2
	exit 4
fi

"$IMAGE_UTIL_DIR/assert-vm.sh" "$BASE_VM" || fail_handler $?

FULL_NAME="`"$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

if virsh list --all | awk  '{print $2}' | grep -q --line-regexp --fixed-strings "$FULL_NAME"; then
	echo "$LIBVIRT_DEFAULT_URI: vm is present. Removing..."
	safe_remove "${GREEN}Vm ${RED}$FULL_NAME${NC}"
	"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$FULL_NAME"
fi

if [ -d "$RESULTS_DIR" ]; then
	echo "removing $RESULTS_DIR"
	rm -rf "$RESULTS_DIR"
fi

mkdir -p "$RESULTS_DIR"
> "$RESULT"

"$IMAGE_UTIL_DIR/get-settings.sh" "$NAME" "$INSTALL_VERSION" | sed -e '1{/.*/d}'> "$RESULT_SETTINGS"

echo -e "${BLUE}preparing $FULL_NAME${NC}"
"$IMAGE_MANAGEMENT_DIR/clone-vm.sh" "$BASE_VM" "$FULL_NAME" || fail_handler $?

virsh start "$FULL_NAME" || fail_handler $?

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
$SSH "root@$IP" "cat /etc/*release" > "$RESULT_RELEASE"

copy_to_remote "$IP" "$BENCHMARK_DIR/dependencies"
copy_to_remote "$IP" "$VERSIONED_INSTALL_DIR/dependencies"

FINAL_SCRIPT="`SCRIPT_FILE="$INSTALL_SCRIPT" POST_SCRIPT_FILE="$VERSIONED_INSTALL_SCRIPT" "$IMAGE_UTIL_DIR/get-settings.sh" "$NAME" "$INSTALL_VERSION"`"
$SSH "root@$IP" "bash -s" -- <<< "$FINAL_SCRIPT" 2>&1 | tee "$VERBOSE_FILE" >> "$RESULT" || fail_handler $?

$SSH "root@$IP" "rm -rf /tmp/dependencies" 2>&1 | tee "$VERBOSE_FILE" >> "$RESULT"

# "$IMAGE_MANAGEMENT_DIR/vm-up.sh" "$FULL_NAME"
virsh shutdown "$FULL_NAME"

echo -e "${BLUE}Install output can be found in `realpath $RESULTS_DIR`${NC}"

