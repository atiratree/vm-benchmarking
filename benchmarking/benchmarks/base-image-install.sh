#!/bin/bash
set -e

sed -i -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
yum -y install gcc wget qemu-guest-agent
yum clean all
rm -rf /var/cache/yum
