#!/bin/bash
# common install file for all versions

includeInSuite(){
    BENCHMARK_SUITE="$1"
    BENCHMARK_NAME="$2"
    BENCHMARK_CLASS="$3"

    if [ -n "$BENCHMARK_CLASS" ]; then
        echo "$BENCHMARK_NAME $BENCHMARK_CLASS" >> "$BENCHMARK_SUITE"
    fi
}

set -e

yum -y install gcc-gfortran

wget https://www.nas.nasa.gov/assets/npb/NPB3.3.1.tar.gz

tar xzf NPB3.3.1.tar.gz

yum clean all
rm -rf /var/cache/yum NPB3.3.1.tar.gz

cd NPB3.3.1/NPB3.3-OMP/

CONFIG="config/make.def"
SUITE="config/suite.def"

cp config/NAS.samples/make.def.gcc_x86 "$CONFIG"

if [ -n "$FFLAGS" ]; then
    sed -i "s/\(FFLAGS\s\+=.*\)/\1 $FFLAGS/g" "$CONFIG"
fi

touch "$SUITE"

# five kernels
includeInSuite "$SUITE" "IS" "$IS"
includeInSuite "$SUITE" "EP" "$EP"
includeInSuite "$SUITE" "CG" "$CG"
includeInSuite "$SUITE" "MG" "$MG"
includeInSuite "$SUITE" "FT" "$FT"

includeInSuite "$SUITE" "BT" "$BT"
includeInSuite "$SUITE" "SP" "$SP"
includeInSuite "$SUITE" "LU" "$LU"

includeInSuite "$SUITE" "DC" "$DC"
includeInSuite "$SUITE" "UA" "$UA"

make suite

echo -e "done\n"
echo "compiled tests:"
ls bin
