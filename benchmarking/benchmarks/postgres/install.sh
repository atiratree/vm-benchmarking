#!/bin/bash
# common install file for all versions

# install how-tos
# https://yum.postgresql.org/howtoyum.php
# https://yum.postgresql.org/files/PostgreSQL-RPM-Installation-PGDG.pdf
# https://people.planetpostgresql.org/devrim/index.php?/#archives/80-Installing-and-configuring-PostgreSQL-9.3-and-9.4-on-RHEL-7.html
# https://developer.ibm.com/linuxonpower/advance-toolchain/advtool-installation/

set -e

ppc64le(){
    # add advance toolchain
    wget ftp://ftp.unicamp.br/pub/linuxpatch/toolchain/at/redhat/RHEL7/gpg-pubkey-6976a827-5164221b
    rpm --import gpg-pubkey-6976a827-5164221b
    rm -f gpg-pubkey-6976a827-5164221b

    echo -e "# Begin of configuration file\n\
[at10.0]\n\
name=Advance Toolchain Unicamp FTP\n\
baseurl=ftp://ftp.unicamp.br/pub/linuxpatch/toolchain/at/redhat/RHEL$CENTOS\n\
failovermethod=priority\n\
enabled=1\n\
gpgcheck=1\n\
gpgkey=ftp://ftp.unicamp.br/pub/linuxpatch/toolchain/at/redhat/RHEL$CENTOS/gpg-pubkey-6976a827-5164221b\
\n# End of configuration file" > /etc/yum.repos.d/at10.0.repo

    YUM_PACKAGES="advance-toolchain-at10.0-runtime"
}

if [ "$ARCHITECTURE" != "x86_64" -a "$ARCHITECTURE" != "ppc64le" ]; then
    echo "Unsupported architecture!" >&2
    exit 1
fi

yum -y install bc

if [ "$ARCHITECTURE" == "ppc64le" ]; then
    ppc64le
fi

# download postgres repository
wget "https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-$ARCHITECTURE/pgdg-centos10-10-2.noarch.rpm"

# download EPEL repository for postgres dependencies 
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# add repos 
yum -y install epel-release-latest-7.noarch.rpm pgdg-centos10-10-2.noarch.rpm

# If you want to run a PostgreSQL server, install postgresql-libs, postgresql and postgresqlserver
yum -y install postgresql10-server postgresql10-contrib postgresql10-libs $YUM_PACKAGES


yum clean all
rm -rf /var/cache/yum epel-release-latest-7.noarch.rpm pgdg-centos10-10-2.noarch.rpm

# init db
/usr/pgsql-10/bin/postgresql-10-setup initdb

# start everytime
systemctl enable postgresql-10

# start service
systemctl start postgresql-10
