#!/bin/bash

# =========================
# Asterisk 20.19.0 Installer (FULL VICIdial + Legacy Compatibility)
# =========================

subdr=required-apps
ver=20.19.0
oem=1

echo -e "\e[0;32m Installing Asterisk v$ver \e[0m"
sleep 2

cd /usr/src

# -------------------------
# CLEAN OLD INSTALLS
# -------------------------
yum remove asterisk -y || true
yum remove asterisk-* -y || true
rm -rf asterisk*

# -------------------------
# DOWNLOAD SOURCE
# -------------------------
if [ $oem -eq 0 ]; then

    wget -O asterisk-$ver-vici.tar.gz \
    http://download.vicidial.com/$subdr/asterisk-$ver-vici.tar.gz

    tar -xvzf asterisk-$ver-vici.tar.gz
    cd asterisk-$ver-vici

elif [ $oem -eq 1 ]; then

    wget -O asterisk-$ver.tar.gz \
    https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-$ver.tar.gz

    tar -xvzf asterisk-$ver.tar.gz
    cd asterisk-$ver
fi

# -------------------------
# CPU THREADS
# -------------------------
: ${JOBS:=$(nproc)}

# -------------------------
# CONFIGURE (MERGED: MODERN + YOUR LEGACY FLAGS)
# -------------------------
echo "Running configure..."

./configure \
    --libdir=/usr/lib64 \
    --with-dahdi=/usr/include/dahdi \
    --with-pri=/usr/lib64 \
    --with-srtp=/usr/lib64 \
    --with-jansson-bundled=no \
    --with-lame=/usr/lib64 \
    --with-gsm=internal \
    --enable-opus \
    --enable-srtp \
    --with-ssl \
    --enable-asteriskssl \
    --with-pjproject-bundled

# -------------------------
# MENUSELECT CONFIG
# -------------------------
make menuselect/menuselect menuselect-tree menuselect.makeopts

# VICIdial required modules
menuselect/menuselect --enable app_meetme menuselect.makeopts
menuselect/menuselect --enable res_http_websocket menuselect.makeopts
menuselect/menuselect --enable res_srtp menuselect.makeopts

# -------------------------
# BUILD
# -------------------------
echo "Compiling Asterisk..."

make -j${JOBS} all

# -------------------------
# INSTALL
# -------------------------
make install
make samples
make config

ldconfig

# -------------------------
# LEGACY SIP HANDLING (VICIdial compatibility)
# -------------------------
sed -i 's|noload = chan_sip.so|;noload = chan_sip.so|g' /etc/asterisk/modules.conf || true

# -------------------------
# SYSTEMD SERVICE FIXED
# -------------------------
cat <<EOF > /etc/systemd/system/asterisk.service
[Unit]
Description=Asterisk PBX
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
PIDFile=/run/asterisk/asterisk.pid
ExecStart=/usr/sbin/asterisk -f -vvvg -c
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable asterisk.service
systemctl restart asterisk.service

systemctl status asterisk.service | head -n 20

echo -e "\e[0;32m Asterisk 20.19.0 installation complete \e[0m"
