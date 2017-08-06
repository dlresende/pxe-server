#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eu

TFTP_ROOT=/tmp/tftp

download_netboot_image() {
  local dist=xenial
  local arch=amd64
  local netboot_image=/tmp/netboot.tar.gz

  wget http://archive.ubuntu.com/ubuntu/dists/$dist/main/installer-$arch/current/images/netboot/netboot.tar.gz \
    -O $netboot_image \
    --quiet

  if [ ! -d $TFTP_ROOT ]
  then
    mkdir -p $TFTP_ROOT
  fi

  tar xf $netboot_image -C $TFTP_ROOT
}

setup_dnsmasq() {
  sudo apt-get update > /dev/null
  sudo apt-get install \
    --assume-yes \
    dnsmasq \

  local ip_address
  ip_address=$(ifconfig | awk '/inet addr/{print substr($2,6)}' | grep 192.168)

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

# This range(s) is for the public interface, where dnsmasq functions
# as a proxy DHCP server providing boot information but no IP leases.
# Any ip in the subnet will do, so you may just put your server NIC ip here.
dhcp-range=$ip_address,proxy
EOF"

  sudo service dnsmasq restart
}

configure_preseed() {
  cp /vagrant/preseed.cfg "$TFTP_ROOT"

  if [ ! -r $TFTP_ROOT/pxelinux.cfg/default.original ]
  then
    cp $TFTP_ROOT/pxelinux.cfg/default $TFTP_ROOT/pxelinux.cfg/default.original
  fi

  sudo sh -c "cat > $TFTP_ROOT/pxelinux.cfg/default << EOF
default install
label install
  kernel ubuntu-installer/amd64/linux
  append vga=788 initrd=ubuntu-installer/amd64/initrd.gz auto=true priority=critical preseed/file=preseed.cfg
EOF"
}

main() {
  download_netboot_image
  setup_dnsmasq
  configure_preseed
}

main
