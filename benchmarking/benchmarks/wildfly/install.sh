#!/bin/bash
# common install file for all versions

set -e

extract(){
    tar xzf "$1" && rm -rf "$1"
}

set_env(){
    echo "export $1" >> ~/.bash_profile
    export $1
}

# install java
yum -y install java-1.8.0-openjdk.x86_64 java-1.8.0-openjdk-devel.x86_64

yum clean all
rm -rf /var/cache/yum

# install maven
cd /usr/local
wget http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz
extract apache-maven-3.5.2-bin.tar.gz
ln -s apache-maven-3.5.2 maven

set_env "M2_HOME=/usr/local/maven"
set_env "PATH=${M2_HOME}/bin:${PATH}"

# install wildfly
cd
wget https://github.com/wildfly/wildfly/archive/12.0.0.Final.tar.gz
extract 12.0.0.Final.tar.gz
cd wildfly-12.0.0.Final
mvn install -DskipTests

# download test dependencies
./integration-tests.sh install -DallTests -DskipTests
