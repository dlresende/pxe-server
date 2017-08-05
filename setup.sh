#!/usr/bin/env sh

[ -z "$DEBUG" ] || set -x

set -u

TFTP_ROOT=/tmp/tftp

if [ ! -d "$TFTP_ROOT" ]; then
  wget http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ \
    --directory-prefix="$TFTP_ROOT" \
    --recursive \
    --no-parent \
    --no-host-directories \
    --cut-dirs=8 \
    --quiet
fi

sudo apt-get update
sudo apt-get install \
  --assume-yes \
  dnsmasq \

IP_ADDRESS=$(ifconfig | awk '/inet addr/{print substr($2,6)}' | grep 192.168)

sudo sh -c "cat > /etc/dnsmasq.d/proxydhcp.conf << EOF
# Set the boot filename for netboot/PXE. You will only need
# this is you want to boot machines over the network and you will need
# a TFTP server; either dnsmasq built's in TFTP server or an
# external one. (See below for how to enable the TFTP server.)
dhcp-boot=pxelinux.0

# Loads <tftp-root>/pxelinux.0 from dnsmasq TFTP server.
pxe-service=x86PC, 'Install Linux', pxelinux

# Enable dnsmasq's built-in TFTP server
enable-tftp

# Set the root directory for files available via FTP.
tftp-root=$TFTP_ROOT

# Log lots of extra information about DHCP transactions.
log-dhcp

dhcp-range=$IP_ADDRESS,proxy
EOF"

sudo service dnsmasq restart

cp /vagrant/preseed.cfg "$TFTP_ROOT"

if [ ! -r $TFTP_ROOT/pxelinux.cfg/default.original ]
then
  cp $TFTP_ROOT/pxelinux.cfg/default $TFTP_ROOT/pxelinux.cfg/default.original
fi

sudo sh -c "cat > $TFTP_ROOT/pxelinux.cfg/default << EOF
default install
label install
  kernel ubuntu-installer/amd64/linux
  append vga=788 initrd=ubuntu-installer/amd64/initrd.gz auto=true priority=critical preseed/url=tftp://$IP_ADDRESS/preseed.cfg
EOF"
