#!/bin/bash

trap cleanup SIGINT

cleanup(){
	echo "killing benchmark $BENCHMARK_VM"
    exitIfFailed 3
}

exitIfFailed(){
	if [ $1 -ne 0 ]; then	
	    echo "exiting unexpectedly: cleaning up"
		if [ -e "$RUN_RESULT" ]; then
			echo "failed with return code $1" >> "$RUN_RESULT"
		fi
		rm -f "$SCRIPT_WITH_ENV_FILE"

		if [ -n "$BENCHMARK_VM" ]; then
		    CLONED_DISK="`"$UTIL_DIR/get-clone-disk-filename.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM"`"
			sync # wait in case script is in the middle of creating image
			"$SCRIPTS_DIR/delete-vm.sh" "$BENCHMARK_VM" "$CLONED_DISK"
		fi
        exit $1
    fi
}

getScriptWithEnv(){
	SCRIPT_WITH_ENV_FILE=$(mktemp /tmp/benchmark-suite.XXXXXX)
	sed -e "/#!\/bin\/bash/r$2" "$1" > "$SCRIPT_WITH_ENV_FILE"
}

runScript(){
	getScriptWithEnv "$3" "$4"
	ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i "$2" "root@$1" "bash -s" -- < "$SCRIPT_WITH_ENV_FILE" 2>&1 | tee "$VERBOSE_FILE" >> "$RUN_RESULT"
	exitIfFailed $?
	rm -f "$SCRIPT_WITH_ENV_FILE"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="$SCRIPTS_DIR/util"
source "$SCRIPTS_DIR/../config.env"


NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"


BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../../benchmarks/`"
BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

INSTALL_BENCHMARK_DIR="$BENCHMARK_DIR/install-v$INSTALL_VERSION"
VERSIONED_RUN_DIR="$INSTALL_BENCHMARK_DIR/run-v$RUN_VERSION"


RESULTS_DIR="$VERSIONED_RUN_DIR/out"
RUN_SCRIPT="$VERSIONED_RUN_DIR/run.sh"
RUN_LIBVIRT_XML="$VERSIONED_RUN_DIR/libvirt.xml"

SETTINGS_ENV="$BENCHMARK_DIR/settings.env"
ID_RSA="`realpath $SCRIPTS_DIR/../generated/id_rsa`"

if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 1
fi

if [ -z "$INSTALL_VERSION" ]; then
	echo "install version must be specified" >&2
	exit 2
fi

if [ -z "$RUN_VERSION" ]; then
	echo "run version must be specified" >&2
	exit 3
fi

if [ ! -e "$RUN_SCRIPT" ]; then
	echo "run script $RUN_SCRIPT must be specified" >&2
	exit 4
fi

if [ ! -e "$SETTINGS_ENV" ]; then
	echo "$SETTINGS_ENV must be specified" >&2
	exit 5
fi


mkdir -p "$RESULTS_DIR"

BENCHMARK_BASE_VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"

"$UTIL_DIR/assert-vm.sh" "$BENCHMARK_BASE_VM"
exitIfFailed $?

ID="`"$UTIL_DIR/get-new-run-id.sh" "$NAME" "$INSTALL_VERSION"  "$RUN_VERSION"`"

BENCHMARK_VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"

RUN_RESULTS_DIR="$RESULTS_DIR/$ID"
RUN_RESULT="$RUN_RESULTS_DIR/output"
RUN_RESULT_LIBVIRT_XML="$RUN_RESULTS_DIR/libvirt.xml"

mkdir -p "$RUN_RESULTS_DIR"
> "$RUN_RESULT"

echo -e "${GREEN}initializing $BENCHMARK_VM benchmark${NC}"
"$SCRIPTS_DIR/clone-vm.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM"
exitIfFailed $?

echo "synchronizing cached writes"
sync

CURRENT_LIBVIRT_XML="`virsh  dumpxml "$BENCHMARK_VM"`"
echo "$CURRENT_LIBVIRT_XML" > "$RUN_RESULT_LIBVIRT_XML"".bak"

if [ -e "$RUN_LIBVIRT_XML" ]; then
	echo "using custom libvirt.xml"	
	UUID_ELEM="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "<uuid>.*<"`"
	MAC_ADDR="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "<mac address='.*'" | head -1`"
	FILE="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "/.*.qcow2" | sed 's;/;\\\/;g' | head -1`"
	sed -e "s/<name>.*<\/name>/<name>$BENCHMARK_VM<\/name>/; s/<uuid>.*</$UUID_ELEM/g; s/\/.*.qcow2/$FILE/; s/<mac address='.*'/$MAC_ADDR/" \
	"$RUN_LIBVIRT_XML" | virsh define /dev/stdin > /dev/null 2>&1
	exitIfFailed $?
fi

virsh dumpxml "$BENCHMARK_VM" > "$RUN_RESULT_LIBVIRT_XML"
exitIfFailed $?

virsh --connect="$CONNECTION" start "$BENCHMARK_VM"
exitIfFailed $?

"$UTIL_DIR/wait-ssh-up.sh" "$BENCHMARK_VM" "$ID_RSA"
IP="`"$UTIL_DIR/get-ip.sh" "$BENCHMARK_VM" "$ID_RSA"`"

# run benchmarks
echo -e "${GREEN}running $BENCHMARK_VM benchmark${NC}"

runScript "$IP" "$ID_RSA" "$RUN_SCRIPT" "$SETTINGS_ENV"

"$SCRIPTS_DIR/delete-vm.sh" "$BENCHMARK_VM"
exitIfFailed $?

echo -e "${GREEN}benchmark successfully finished${NC}"
