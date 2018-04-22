#!/bin/bash

set -eu

cd /tmp
tar xzf sysstat-v11.7.2.tar.gz
cd sysstat-11.7.2/
./configure --with-systemdsystemunitdir=/usr/lib/systemd/system --enable-install-cron
make install

systemctl enable sysstat
systemctl start sysstat
