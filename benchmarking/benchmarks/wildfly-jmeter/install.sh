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


wget http://mirror.hosting90.cz/apache/jmeter/binaries/apache-jmeter-4.0.tgz
extract "apache-jmeter-4.0.tgz"

cp  /tmp/dependencies/daytrader.jmx .

echo "done"
