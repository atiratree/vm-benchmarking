#!/bin/bash

trap cleanup SIGINT SIGTERM

cleanup(){
	echo "killing benchmark $BENCHMARK_VM"
	after_run
    finish_all 3
}

force_write_buffers(){
    if [ -d "$RUN_POOL_LOCATION" ]; then
        # write random stuff if write cache/buffers are used
        FLUSH_CACHE_TMP="$RUN_POOL_LOCATION/flush-cache.tmp"
        dd if=/dev/urandom of="$FLUSH_CACHE_TMP" iflag=fullblock bs=64M count=16 &> /dev/null
    fi
}

force_flush_read_buffers(){
    if [ -f "$FLUSH_CACHE_TMP" ]; then
        echo "force overwriting disk buffers"
        dd if="$FLUSH_CACHE_TMP" iflag=fullblock of=/dev/null &> /dev/null
    else
        echo -e "${RED}could not force overwrite disk buffers because RUN_POOL_LOCATION is missing in global-config.env${NC}"
    fi
}

before_run(){
    OLD_SWAPPINGESS="`cat /proc/sys/vm/swappiness`"
    sysctl vm.swappiness=0 &> /dev/null

    echo "synchronizing cached writes"
    sync
    # after sync so only garbage is in write buffers
    force_write_buffers
    sync

    echo "freeing caches"
    swapoff -a && swapon -a &> /dev/null
    # free pagecache, dentries and inodes:
    echo 3 > /proc/sys/vm/drop_caches

    echo "freeing buffers"
    # excludes floppies and optical drives
    for DEVICE in `lsblk  --list --nodeps --noheadings --output NAME --exclude 2,11`; do
        blockdev --flushbufs /dev/"$DEVICE" &> /dev/null
        hdparm -fF /dev/"$DEVICE" &> /dev/null
    done
    force_flush_read_buffers
    # free caches again after write
    echo 3 > /proc/sys/vm/drop_caches
}

after_run(){
    sysctl vm.swappiness="$OLD_SWAPPINGESS" &> /dev/null
    rm -f "$FLUSH_CACHE_TMP"
}

finish_all(){
    echo "exiting unexpectedly"
    rm -f "/tmp/get-settings.*"

    if [ -n "$V_BENCHMARK_VM" ]; then
        finish "$V_BENCHMARK_VM" "$V_RUN_RESULT" "$1"
    fi

    # remove unitialized vm
    if [ -z "$V_BENCHMARK_VM" ] || [ -n "$MANAGED_BY_VM" -a -z "$M_BENCHMARK_VM" ]; then
        finish "$BENCHMARK_VM" "$RUN_RESULT" "$1"
        exit $1
    fi

    if [ -n "$MANAGED_BY_VM" -a -n "$M_BENCHMARK_VM" ]; then
        finish "$M_BENCHMARK_VM" "$M_RUN_RESULT" "$1"
    fi

    exit $1
}

finish(){
    F_BENCHMARK_VM="$1"
    F_RUN_RESULT="$2"
    F_RETURN_CODE="$3"

    echo "cleaning up $F_BENCHMARK_VM"

    if [ -e "$F_RUN_RESULT" ]; then
        echo "failed with exit code $F_RETURN_CODE" >> "$F_RUN_RESULT"
    fi

    if [ -n "$F_BENCHMARK_VM" ]; then
        CLONED_DISK="`POOL_LOCATION="$RUN_POOL_LOCATION" "$IMAGE_UTIL_DIR/get-new-disk-filename.sh" "$F_BENCHMARK_VM"`"
        sync # wait in case script is in the middle of creating image
        sleep 10
        "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$F_BENCHMARK_VM" "$CLONED_DISK"
    fi
}

initialize_run(){
    I_NAME="$1"
    I_INSTALL_VERSION="$2"
    I_RUN_VERSION="$3"

    BENCHMARK_DIR="$BENCHMARKS_DIR/$I_NAME"
    INSTALL_BENCHMARK_DIR="$BENCHMARK_DIR/install-v$I_INSTALL_VERSION"
    VERSIONED_RUN_DIR="$INSTALL_BENCHMARK_DIR/run-v$I_RUN_VERSION"

    RESULTS_DIR="$VERSIONED_RUN_DIR/out"
    SCRIPT="$VERSIONED_RUN_DIR/run.sh"

    if [ ! -e "$SCRIPT" ]; then
        echo "run script $SCRIPT must be specified" >&2
        exit 4
    fi

    mkdir -p "$RESULTS_DIR"

    BENCHMARK_BASE_VM="`"$BENCH_UTIL_DIR/get-name.sh" "$I_NAME" "$I_INSTALL_VERSION"`"

    "$IMAGE_UTIL_DIR/assert-vm.sh" "$BENCHMARK_BASE_VM" || finish_all $?

    ID="`"$BENCH_UTIL_DIR/get-new-run-id.sh" "$I_NAME" "$I_INSTALL_VERSION"  "$I_RUN_VERSION"`"

    CACHE_BENCHMARK_VM="`"$BENCH_UTIL_DIR/get-name.sh" "$I_NAME" "$I_INSTALL_VERSION" "$I_RUN_VERSION" "$ID"`"
    BENCHMARK_VM="`"$BENCH_UTIL_DIR/get-name.sh" "$I_NAME" "$I_INSTALL_VERSION" "$I_RUN_VERSION" "$ID"`"
    echo -e "${BLUE}initializing $BENCHMARK_VM${NC}"

    RUN_RESULTS_DIR="$RESULTS_DIR/$ID"
    RUN_RESULT="$RUN_RESULTS_DIR/output"
    RUN_RESULT_SETTINGS="$RUN_RESULTS_DIR/settings.env"
    RUN_RESULT_GLOBAL_CONFIG="$RUN_RESULTS_DIR/global-config.env"

    mkdir -p "$RUN_RESULTS_DIR"

    > "$RUN_RESULT"
    "$BENCH_UTIL_DIR/get-settings.sh" "$I_NAME" "$I_INSTALL_VERSION" "$I_RUN_VERSION" | sed -e '1{/.*/d}'> "$RUN_RESULT_SETTINGS"
    sed -e "/^#.*/d; /^\s*$/d; /^\s*#.*$/d; s/[\"\']*//g" "$GLOBAL_CONFIG" > "$RUN_RESULT_GLOBAL_CONFIG"

    RUN_SCRIPT="`SCRIPT_FILE="$SCRIPT" "$BENCH_UTIL_DIR/get-settings.sh" "$I_NAME" "$I_INSTALL_VERSION" "$I_RUN_VERSION"`"

    if [ -d "$IMAGES_CACHE_LOCATION" ]; then
        clone_with_cached_disk
    else
        POOL_LOCATION="$RUN_POOL_LOCATION" "$IMAGE_MANAGEMENT_DIR/clone-vm.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM" || finish_all $?
    fi
}

clone_with_cached_disk(){
    CACHE_BENCHMARK_VM="`"$BENCH_UTIL_DIR/get-name.sh" "$I_NAME" "$I_INSTALL_VERSION" "$I_RUN_VERSION"`"
    CACHED_DISK_FILENAME="`POOL_LOCATION="$IMAGES_CACHE_LOCATION" "$IMAGE_UTIL_DIR"/get-new-disk-filename.sh "$CACHE_BENCHMARK_VM"`"
    NEW_DISK_FILENAME="`POOL_LOCATION="$RUN_POOL_LOCATION" "$IMAGE_UTIL_DIR"/get-new-disk-filename.sh "$BENCHMARK_VM"`"

    if [ ! -e "$CACHED_DISK_FILENAME" ]; then
	    echo -e "${BLUE}creating cached disk at $CACHED_DISK_FILENAME${NC}"
        POOL_LOCATION="$IMAGES_CACHE_LOCATION" DISK_ONLY=yes "$IMAGE_MANAGEMENT_DIR/clone-vm.sh" \
            "$BENCHMARK_BASE_VM" "$CACHE_BENCHMARK_VM" > /dev/null || finish_all $?
	fi

	echo -e "${GREEN}copying cached disk${NC}"
	echo "$CACHED_DISK_FILENAME -> $NEW_DISK_FILENAME"
    cp "$CACHED_DISK_FILENAME" "$NEW_DISK_FILENAME"

    "$IMAGE_MANAGEMENT_DIR/clone-vm.sh" "$BENCHMARK_BASE_VM" "$BENCHMARK_VM" "$NEW_DISK_FILENAME" 2> /dev/null
}

resolve_libvirt_xml(){
    R_BENCHMARK_VM="$1"
    R_RUN_RESULTS_DIR="$2"

    RUN_LIBVIRT_XML="$R_RUN_RESULTS_DIR/../../libvirt.xml"
    RUN_RESULT_LIBVIRT_XML="$R_RUN_RESULTS_DIR/libvirt.xml"

    CURRENT_LIBVIRT_XML="`virsh  dumpxml "$R_BENCHMARK_VM"`"
    echo "$CURRENT_LIBVIRT_XML" > "$RUN_RESULT_LIBVIRT_XML"".bak"

    if [ -e "$RUN_LIBVIRT_XML" ]; then
        echo -e "${BLUE}$R_BENCHMARK_VM:${NC} using custom libvirt.xml"
        UUID_ELEM="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "<uuid>.*<"`"
        MAC_ADDR="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "<mac address='.*'" | head -1`"
        FILE="`echo "$CURRENT_LIBVIRT_XML" | grep -Eo "/.*\.[a-zA-Z0-9]+" | sed 's;/;\\\/;g' | head -1`"
        sed -e "s/<name>.*<\/name>/<name>$R_BENCHMARK_VM<\/name>/; s/<uuid>.*</$UUID_ELEM/g; s/\/.*\.[a-zA-Z0-9]\+/$FILE/; s/<mac address='.*'/$MAC_ADDR/" \
        "$RUN_LIBVIRT_XML" | virsh define /dev/stdin > /dev/null 2>&1 || finish_all $?
    fi

    virsh dumpxml "$R_BENCHMARK_VM" > "$RUN_RESULT_LIBVIRT_XML" || finish_all $?
}

start_vm(){
    S_BENCHMARK_VM="$1"
    virsh --connect="$CONNECTION" start "$S_BENCHMARK_VM" || finish_all $?

    "$IMAGE_UTIL_DIR/wait-ssh-up.sh" "$S_BENCHMARK_VM"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Could not connect to the vm!${NC}"
        "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$S_BENCHMARK_VM"
        exit 6
    fi

    IP="`"$IMAGE_UTIL_DIR/get-ip.sh" "$S_BENCHMARK_VM"`"

    echo "running $S_BENCHMARK_VM "
}

measure_resources(){
    S_IP="$1"
    S_RUN_RESULTS_DIR="$2"
    if [ "$MEASURE_RESOURCE_USAGE" == "yes" ]; then
        $SSH "root@$S_IP" "df -h" 2> /dev/null > "$S_RUN_RESULTS_DIR/start-disk-usage.txt"

        $SCP "$GENERATED_DIR/$SYSTAT_FILENAME" "root@$S_IP:/tmp/" &> /dev/null

        $SSH "root@$S_IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/init-measurement.sh" &> /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${BLUE}$S_IP: measuring resource usage!${NC}"
            $SSH "root@$S_IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/measure.sh" &> /dev/null &
            MEASURE_PROCESS=$!
            sleep 3 # baseline
        fi
    fi
}


finish_measuring_resources(){
    C_IP="$1"
    C_RUN_RESULTS_DIR="$2"
    C_MEASURE_PROCESS="$3"
    if [ "$MEASURE_RESOURCE_USAGE" == "yes" ]; then
        kill "$C_MEASURE_PROCESS"
        $SSH "root@$C_IP" "bash -s" -- < "$RESOURCE_USAGE_DIR/finish-measurement.sh" &> /dev/null
        $SCP "root@$C_IP:/tmp/sar-report.svg" "$C_RUN_RESULTS_DIR/resource-usage.svg" &> /dev/null
        $SSH "root@$C_IP" "df -h" 2> /dev/null > "$C_RUN_RESULTS_DIR/end-disk-usage.txt"
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath "$SCRIPTS_DIR/../image-management"`"
BENCHMARKS_DIR="`realpath "$IMAGE_MANAGEMENT_DIR/../../benchmarks/"`"

RESOURCE_USAGE_DIR="$SCRIPTS_DIR/resource-usage"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$SCRIPTS_DIR/util"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"

source "$UTIL_DIR/common.sh"


NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
OPTIONS="$4"

set_option "$OPTIONS" "MEASURE_RESOURCE_USAGE"
set_option "$OPTIONS" "MANAGED_BY_VM"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

assert_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"

if [ ! -d "$RUN_POOL_LOCATION" ]; then
    echo "RUN_POOL_LOCATION must be specified" >&2
    exit 5
fi

if [ "$MEASURE_RESOURCE_USAGE" == "yes" ] && [ ! -e "$GENERATED_DIR/$SYSTAT_FILENAME" ]; then
   echo "run init-base-image to download dependencies first" >&2
   exit 6
fi

initialize_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"
V_BENCHMARK_VM="$BENCHMARK_VM"
V_RUN_RESULTS_DIR="$RUN_RESULTS_DIR"
V_RUN_RESULT="$RUN_RESULT"
V_RUN_SCRIPT="$RUN_SCRIPT"

if [ -n "$MANAGED_BY_VM" ]; then
    initialize_run "$MANAGED_BY_VM" "$INSTALL_VERSION" "$RUN_VERSION"
    M_RUN_RESULTS_DIR="$RUN_RESULTS_DIR"
    M_BENCHMARK_VM="$BENCHMARK_VM"
    M_RUN_RESULT="$RUN_RESULT"
    M_RUN_SCRIPT="$RUN_SCRIPT"
fi

before_run

resolve_libvirt_xml "$V_BENCHMARK_VM" "$V_RUN_RESULTS_DIR"
if [ -n "$MANAGED_BY_VM" ]; then
    resolve_libvirt_xml "$M_BENCHMARK_VM" "$M_RUN_RESULTS_DIR"
fi

start_vm "$V_BENCHMARK_VM"
V_IP="$IP"

if [ -n "$MANAGED_BY_VM" ]; then
    start_vm "$M_BENCHMARK_VM"
    M_IP="$IP"
fi

measure_resources "$V_IP" "$V_RUN_RESULTS_DIR"
V_MEASURE_PROCESS="$MEASURE_PROCESS"
if [ -n "$MANAGED_BY_VM" ]; then
    measure_resources "$M_IP" "$M_RUN_RESULTS_DIR"
    M_MEASURE_PROCESS="$MEASURE_PROCESS"
fi

echo -e "${GREEN}running benchmark${NC}"
echo "started: `date`"
START=`date +%s`
FINAL_OUTPUT="/tmp/benchmark-output"

$SSH "root@$V_IP" "bash -s" -- <<< "$V_RUN_SCRIPT" 2>&1 | tee "$VERBOSE_FILE" >> "$V_RUN_RESULT"

if [ -n "$MANAGED_BY_VM" ]; then
    echo -e "${GREEN}benchmark is managed by $M_BENCHMARK_VM${NC}"
    M_RUN_SCRIPT="`echo "$M_RUN_SCRIPT" | sed -e "s/#\!\/bin\/bash/#\!\/bin\/bash\nIP=$V_IP/g"`"
    $SSH "root@$M_IP" "bash -s" -- <<< "$M_RUN_SCRIPT" 2>&1 | tee "$VERBOSE_FILE" >> "$M_RUN_RESULT"
    $SSH "root@$M_IP" "[ -f $FINAL_OUTPUT ] && cat  $FINAL_OUTPUT"  2>&1 | tee "$VERBOSE_FILE" >> "$M_RUN_RESULT"
fi
$SSH "root@$V_IP" "[ -f $FINAL_OUTPUT ] && cat  $FINAL_OUTPUT"  2>&1 | tee "$VERBOSE_FILE" >> "$V_RUN_RESULT"


END=`date +%s`

finish_measuring_resources "$V_IP" "$V_RUN_RESULTS_DIR" "$V_MEASURE_PROCESS"

if [ -n "$MANAGED_BY_VM" ]; then
    finish_measuring_resources "$M_IP" "$M_RUN_RESULTS_DIR" "$M_MEASURE_PROCESS"
fi

if [ -n "$MANAGED_BY_VM" ]; then
    "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$M_BENCHMARK_VM"
fi
"$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$V_BENCHMARK_VM"|| finish_all $?


echo -e "\nBenchmark Runtime: $((END-START)) s"
echo -e "${GREEN}benchmark successfully finished${NC}"
after_run
