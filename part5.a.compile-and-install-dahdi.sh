#!/bin/sh

ver=3.4.0
oem=0

echo -e "\e[0;32m Install Dahdi Audio_CODEC Driver v$ver \e[0m"
sleep 2

cd /usr/src
yum install kernel-devel-$(uname -r) -y

yum remove dahdi* -y
yum remove dahdi-tools* -y

if [ $oem -eq 1 ]
then
	wget http://download.vicidial.com/required-apps/dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	tar -xvzf dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	cd dahdi-linux-complete-2.3.0.1+2.3.0
elif [ $oem -eq 0 ]
then
	wget -O dahdi-linux-complete-$ver+$ver.tar.gz https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-$ver+$ver.tar.gz
	tar -xvzf dahdi-linux-complete-$ver+$ver.tar.gz
	cd dahdi-linux-complete-$ver+$ver

	echo "Applying DAHDI source patches for Kernel 6.12 compatibility..."

	sed -i 's/static int span_match(struct device \*dev, struct device_driver \*driver)/static int span_match(struct device *dev, const struct device_driver *driver)/' linux/drivers/dahdi/dahdi-sysfs.c

	sed -i 's/static int chan_match(struct device \*dev, struct device_driver \*driver)/static int chan_match(struct device *dev, const struct device_driver *driver)/' linux/drivers/dahdi/dahdi-sysfs-chan.c

	sed -i 's/static int astribank_match(struct device \*dev, struct device_driver \*driver)/static int astribank_match(struct device *dev, const struct device_driver *driver)/; s/static int xpd_match(struct device \*dev, struct device_driver \*driver)/static int xpd_match(struct device *dev, const struct device_driver *driver)/' linux/drivers/dahdi/xpp/xbus-sysfs.c

	sed -i 's/from_timer(wc, timer, timer)/container_of(timer, struct t13x, timer)/' linux/drivers/dahdi/wcte13xp-base.c

	sed -i 's/from_timer(wc, timer, timer)/container_of(timer, struct t43x, timer)/' linux/drivers/dahdi/wcte43x-base.c

	sed -i 's/from_timer(wc, timer, watchdog)/container_of(timer, struct wcdte, watchdog)/' linux/drivers/dahdi/wctc4xxp/base.c

	sed -i 's/from_timer(wc, timer, timer)/container_of(timer, struct t1, timer)/' linux/drivers/dahdi/wcte12xp/base.c

	sed -i 's/from_timer(vb, timer, timer)/container_of(timer, struct voicebus, timer)/' linux/drivers/dahdi/voicebus/voicebus.c

	sed -i 's/from_timer(xbus, timer, command_timer)/container_of(timer, xbus_t, command_timer)/' linux/drivers/dahdi/xpp/xbus-pcm.c

	sed -i '142s/^/## /' linux/drivers/dahdi/Kbuild

	echo "DAHDI Kernel 6.12 patches applied."
fi

: ${JOBS:=$(nproc)}

make -j ${JOBS} all
make install
make config
make install-config

modprobe dahdi
modprobe dahdi_dummy

dahdi_genconf -v
dahdi_cfg -v

cd tools
make clean
make -j ${JOBS} all
make install
make install-config

cd /etc/dahdi

\cp -r system.conf system.conf.bak
\cp -r system.conf.sample system.conf

echo -e "\e[0;32m Enable dahdi.service in systemctl \e[0m"
sleep 2

\cp -r /etc/systemd/system/dahdi.service /etc/systemd/system/dahdi.service.bak 2>/dev/null
rm -rf /etc/systemd/system/dahdi.service
touch /etc/systemd/system/dahdi.service

tee /etc/systemd/system/dahdi.service <<'EOF'
[Unit]
Description=DAHDI Telephony Drivers
After=network.target
Before=asterisk.service

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe dahdi
ExecStartPre=/sbin/modprobe dahdi_dummy
ExecStart=/usr/sbin/dahdi_cfg -v
ExecReload=/usr/sbin/dahdi_cfg -v
ExecStop=/usr/sbin/dahdi_cfg -v
Restart=on-failure
RestartSec=2
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && \
systemctl disable dahdi.service && \
systemctl enable dahdi.service && \
systemctl restart dahdi.service && \
systemctl status dahdi.service | head -n 18

\cp -r /dahdi.sh /dahdi.sh.bak 2>/dev/null
rm -rf /dahdi.sh
\cp -r /usr/src/dahdi.sh /dahdi.sh

chmod +x /dahdi.sh
