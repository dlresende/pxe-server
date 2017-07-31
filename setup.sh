#!/usr/bin/env sh

[ -z "$DEBUG" ] || set -x

set -eu

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
# Listen on this specific port instead of the standard DNS port
# (53). Setting this to zero completely disables DNS function,
# leaving only DHCP and/or TFTP.
port=0

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
