#!/bin/bash
# common install file for all versions

set -e
# install how-tos
# https://yum.postgresql.org/howtoyum.php
# https://yum.postgresql.org/files/PostgreSQL-RPM-Installation-PGDG.pdf
# https://people.planetpostgresql.org/devrim/index.php?/#archives/80-Installing-and-configuring-PostgreSQL-9.3-and-9.4-on-RHEL-7.html

yum -y install wget bc

# download postgres repository
wget https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm

# download EPEL repository for postgres dependencies 
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# add repos 
yum -y install epel-release-latest-7.noarch.rpm pgdg-centos10-10-2.noarch.rpm

# If you want to run a PostgreSQL server, install postgresql-libs, postgresql and postgresqlserver
yum -y install postgresql10-server postgresql10-contrib postgresql10-libs


yum clean all
rm -rf /var/cache/yum epel-release-latest-7.noarch.rpm pgdg-centos10-10-2.noarch.rpm

# init db
/usr/pgsql-10/bin/postgresql-10-setup initdb

# start everytime
systemctl enable postgresql-10

# start service
systemctl start postgresql-10
