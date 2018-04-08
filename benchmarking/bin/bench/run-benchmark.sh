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
		rm -f "$TMP_FILE" "/tmp/get-settings.*"

		if [ -n "$BENCHMARK_VM" ]; then
		    CLONED_DISK="`"$UTIL_DIR/get-clone-disk-filename.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM"`"
			sync # wait in case script is in the middle of creating image
			"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$BENCHMARK_VM" "$CLONED_DISK"
		fi
        exit $1
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath $SCRIPTS_DIR/../image-management`"
RESOURCE_USAGE_DIR="$SCRIPTS_DIR/resource-usage"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/../config.env"


NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
MEASURE_RESOURCE_USAGE="$4"


BENCHMARKS_DIR="`realpath $IMAGE_MANAGEMENT_DIR/../../benchmarks/`"
BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

INSTALL_BENCHMARK_DIR="$BENCHMARK_DIR/install-v$INSTALL_VERSION"
VERSIONED_RUN_DIR="$INSTALL_BENCHMARK_DIR/run-v$RUN_VERSION"

RESULTS_DIR="$VERSIONED_RUN_DIR/out"
RUN_SCRIPT="$VERSIONED_RUN_DIR/run.sh"
RUN_LIBVIRT_XML="$VERSIONED_RUN_DIR/libvirt.xml"

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

if [ "$MEASURE_RESOURCE_USAGE" == "yes" ] && [ ! -e "$GENERATED_DIR/$SYSTAT_FILENAME" ]; then
   echo "run init-base-image to download dependencies first" >&2
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

echo -e "${BLUE}initializing $BENCHMARK_VM benchmark${NC}"
"$IMAGE_MANAGEMENT_DIR/clone-vm.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM"
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

"$UTIL_DIR/wait-ssh-up.sh" "$BENCHMARK_VM"
IP="`"$UTIL_DIR/get-ip.sh" "$BENCHMARK_VM"`"

# run benchmarks
echo -e "${GREEN}running $BENCHMARK_VM benchmark${NC}"

FINAL_SCRIPT="`SCRIPT_FILE="$RUN_SCRIPT" "$UTIL_DIR/get-settings.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"

if [ "$MEASURE_RESOURCE_USAGE" == "yes" ]; then
    $SCP "$GENERATED_DIR/$SYSTAT_FILENAME" "root@$IP:/tmp/" &> /dev/null

    $SSH "root@$IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/init-measurement.sh" &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}measuring resource usage!${NC}"
        $SSH "root@$IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/measure.sh" &> /dev/null &
        MEASURE_PROCESS=$!
        sleep 3 # baseline
    fi
    START=`date +%s`
fi
echo "started: `date`"
$SSH "root@$IP" "bash -s" -- <<< "$FINAL_SCRIPT" 2>&1 | tee "$VERBOSE_FILE" >> "$RUN_RESULT"


if [ "$MEASURE_RESOURCE_USAGE" == "yes" ]; then
    END=`date +%s`
    kill "$MEASURE_PROCESS"
    $SSH "root@$IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/finish-measurement.sh" &> /dev/null
    $SCP "root@$IP:/tmp/sar-report.svg" "$RUN_RESULTS_DIR/resource-usage.svg" &> /dev/null
    SPACE_USAGE="`$SSH "root@$IP" "df -h" 2> /dev/null`"
fi

"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$BENCHMARK_VM"
exitIfFailed $?

echo -e "${GREEN}benchmark successfully finished${NC}"


if [ "$MEASURE_RESOURCE_USAGE" == "yes" ]; then
    echo -e "\nBenchmark Runtime: $((END-START)) s"
    echo -e "\nBenchmark Space Usage:\n $SPACE_USAGE"
fi
