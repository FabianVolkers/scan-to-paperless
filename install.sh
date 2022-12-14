#!/usr/bin/env bash

if [ "$USER" != 'root' ];then
    echo Install script must be run as root, aborting.
fi

echo Installing required packages
apt update && apt install -y \
    sane \
    netpbm \
    pdftk \
    ghostscript \
    bc

echo Getting brother drivers
curl -o ~/brscan4-0.4.11-1.amd64.deb https://download.brother.com/welcome/dlf105200/brscan4-0.4.11-1.amd64.deb
curl -o ~/brscan-skey-0.3.1-2.amd64.deb https://download.brother.com/welcome/dlf006652/brscan-skey-0.3.1-2.amd64.deb
curl -o ~/brotherlegacyusb-1.1.0-1.all.deb https://download.brother.com/welcome/dlf105260/brotherlegacyusb-1.1.0-1.all.deb

echo Installing brother drivers
apt install \
    ~/brscan4-0.4.11-1.amd64.deb \
    ~/brscan-skey-0.3.1-2.amd64.deb \
    ~/brotherlegacyusb-1.1.0-1.all.deb

# create user brscan-skey
useradd -M brscan-skey
usermod -L brscan-skey
usermod -aG lp brscan-skey

echo Installing scan-to-paperless
curl -o /opt/brother/scanner/brscan-skey/script/scantopaperless.sh https://raw.githubusercontent.com/FabianVolkers/scan-to-paperless/main/scantopaperless.sh
curl -o /opt/brother/scanner/brscan-skey/brscan-skey.config https://raw.githubusercontent.com/FabianVolkers/scan-to-paperless/main/brscan-skey.config
curl -o /etc/systemd/system/brscan-skey.service https://raw.githubusercontent.com/FabianVolkers/scan-to-paperless/main/brscan-skey.service
if [ "$(find /opt/brother/scanner/brscan-skey/script/.env)" == '' ];then
    curl -o /opt/brother/scanner/brscan-skey/script/.env https://raw.githubusercontent.com/FabianVolkers/scan-to-paperless/main/.env
fi

# TODO:
# interactive .env configuration

echo scan-to-paperless successfully installed
echo Adapt /opt/brother/scanner/brscan-skey/script/.env to your needs