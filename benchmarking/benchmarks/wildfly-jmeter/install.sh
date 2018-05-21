#!/bin/bash
# common install file for all versions

set -eu

extract(){
    tar xzf "$1" && rm -rf "$1"
}

# install java
yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel

yum clean all
rm -rf /var/cache/yum


ARCHIVE_NAME="apache-jmeter.tgz"
wget -O "$ARCHIVE_NAME" "$APACHE_JMETER_MIRROR"
extract "$ARCHIVE_NAME"

cp  /tmp/dependencies/daytrader.jmx .

echo "done"
