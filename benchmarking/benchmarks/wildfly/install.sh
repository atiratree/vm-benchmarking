#!/bin/bash
# common install file for all versions

set -eu

extract(){
    tar xzf "$1" && rm -rf "$1"
}

set_env(){
    echo "export $1" >> ~/.bash_profile
    export $1
}

# install java
yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel

yum clean all
rm -rf /var/cache/yum

# install maven
cd /usr/local
ARCHIVE_NAME="apache-maven.tar.gz"
wget -O "$ARCHIVE_NAME" "$APACHE_MAVEN_MIRROR"

extract "$ARCHIVE_NAME"
ln -s "apache-maven-$APACHE_MAVEN_VERSION" maven

set_env "M2_HOME=/usr/local/maven"
set_env "PATH=${M2_HOME}/bin:${PATH}"

# install wildfly
cd
wget https://github.com/wildfly/wildfly/archive/12.0.0.Final.tar.gz
extract 12.0.0.Final.tar.gz
cd wildfly-12.0.0.Final
ulimit -n 8192
mvn install -DskipTests
cd
