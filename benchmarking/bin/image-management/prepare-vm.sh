#!/bin/bash

exitIfFailed(){
	if [ $1 -ne 0 ]; then	
	    echo "exiting unexpectedly: cleaning up"
		if [ -e "$RESULT" ]; then
			echo "failed with return code $1" >> "$RESULT"
		fi
		rm -f "$SCRIPT_WITH_ENV_FILE"
		"$SCRIPTS_DIR/delete-vm.sh" "$NAME"
        exit $?
    fi
}

getScriptWithEnv(){
	SCRIPT_WITH_ENV_FILE=$(mktemp /tmp/benchmark-suite.XXXXXX)
	sed -e "/#!\/bin\/bash/r$2" "$1" > "$SCRIPT_WITH_ENV_FILE"
}

runScript(){
	getScriptWithEnv "$3" "$4"
	ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i "$2" "root@$1" "bash -s" -- < "$SCRIPT_WITH_ENV_FILE" 2>&1 | tee "$VERBOSE_FILE" >> "$RESULT"
	exitIfFailed $?
	rm -f "$SCRIPT_WITH_ENV_FILE"
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


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="$SCRIPTS_DIR/util"
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

INSTALL_DIR_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
VERSIONED_INSTALL_DIR="$BENCHMARKS_DIR/$INSTALL_DIR_PART"

INSTALL_SCRIPT="$BENCHMARK_DIR/install.sh"
VERSIONED_INSTALL_SCRIPT="$VERSIONED_INSTALL_DIR/install.sh"
SETTINGS_ENV="$BENCHMARK_DIR/settings.env"

RESULTS_DIR="$VERSIONED_INSTALL_DIR/out"
RESULT="$RESULTS_DIR/output"

ID_RSA="`realpath $SCRIPTS_DIR/../generated/id_rsa`"

if [ ! -e "$INSTALL_SCRIPT" ]; then
	echo "install script $INSTALL_SCRIPT must be specified" >&2
	exit 4
fi

if [ ! -e "$SETTINGS_ENV" ]; then
	echo "settings.env $SETTINGS_ENV must be specified" >&2
	exit 5
fi

"$UTIL_DIR/assert-vm.sh" "$BASE_VM"
exitIfFailed $?

NAME="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

if virsh list --all | awk  '{print $2}' | grep -q --line-regexp --fixed-strings "$NAME"; then
	echo "$LIBVIRT_DEFAULT_URI: vm is present. Removing..."
	safeRemove "${GREEN}Vm ${RED}$NAME${NC}"
	"$SCRIPTS_DIR/delete-vm.sh" "$NAME"	
fi

if [ -d "$RESULTS_DIR" ]; then
	echo "removing $RESULTS_DIR"
	rm -rf "$RESULTS_DIR"
fi

mkdir -p "$RESULTS_DIR"
> "$RESULT"

echo -e "${GREEN}preparing $NAME${NC}"
"$SCRIPTS_DIR/clone-vm.sh" "$BASE_VM" "$NAME"
exitIfFailed $?

virsh start "$NAME"
exitIfFailed $?


"$UTIL_DIR/wait-ssh-up.sh" "$NAME" "$ID_RSA"
IP="`"$UTIL_DIR/get-ip.sh" "$NAME" "$ID_RSA"`"

# install
echo -e "${GREEN}Installing${NC}"


runScript "$IP" "$ID_RSA" "$INSTALL_SCRIPT" "$SETTINGS_ENV"

if [ -e "$VERSIONED_INSTALL_SCRIPT" ]; then
	# install versioned
	echo -e "${GREEN}Installing addon: `realpath $VERSIONED_INSTALL_SCRIPT`${NC}"
	runScript "$IP" "$ID_RSA" "$VERSIONED_INSTALL_SCRIPT" "$SETTINGS_ENV"
fi

# "$SCRIPTS_DIR/vm-up.sh" "$NAME"
virsh shutdown "$NAME"

echo -e "${GREEN}Install output can be found in `realpath $RESULTS_DIR`${NC}"

