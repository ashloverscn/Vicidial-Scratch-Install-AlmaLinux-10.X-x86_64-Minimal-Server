#!/bin/sh
#ver=3.1.0
#oem=1
ver=3.4.0
oem=0

echo -e "\e[0;32m Install Dahdi Audio_CODEC Driver v$ver \e[0m"
sleep 2
cd /usr/src
yum install kernel-devel-$(uname -r) -y
#rm -rf dahdi-linux-complete*
yum remove dahdi* -y
yum remove dahdi-tools* -y
#yum install dahdi* -y
#yum install dahdi-tools* -y
if [ $oem -eq 1 ]
then
	wget http://download.vicidial.com/required-apps/dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	tar -xvzf dahdi-linux-complete-2.3.0.1+2.3.0.tar.gz
	cd dahdi-linux-complete-2.3.0.1+2.3.0
else
	wget -O dahdi-linux-complete-$ver+$ver.tar.gz https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-$ver+$ver.tar.gz
	tar -xvzf dahdi-linux-complete-$ver+$ver.tar.gz
	cd dahdi-linux-complete-$ver+$ver

	#####################################################################################################################################################
	echo "Starting DAHDI patches for Kernel 6.12 compatibility..."
	
	# 1. Fix Core DAHDI Sysfs match signatures
	# We use a check to ensure we don't add 'const' twice
	if ! grep -q "const struct device_driver \*driver" linux/drivers/dahdi/dahdi-sysfs.c; then
	    sed -i 's/struct device_driver \*driver/const struct device_driver *driver/g' linux/drivers/dahdi/dahdi-sysfs.c
	fi
	
	if ! grep -q "const struct device_driver \*driver" linux/drivers/dahdi/dahdi-sysfs-chan.c; then
	    sed -i 's/struct device_driver \*driver/const struct device_driver *driver/g' linux/drivers/dahdi/dahdi-sysfs-chan.c
	fi
	
	# 2. Fix XPP (Astribank) Bus Match
	if [ -f linux/drivers/dahdi/xpp/xbus-sysfs.c ]; then
	    # Specifically target match functions
	    sed -i 's/astribank_match(struct device \*dev, struct device_driver \*driver)/astribank_match(struct device *dev, const struct device_driver *driver)/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	    sed -i 's/xpd_match(struct device \*dev, struct device_driver \*driver)/xpd_match(struct device *dev, const struct device_driver *driver)/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	fi
	
	# 3. Revert XPP Attributes and Registration to NON-CONST
	# These must remain non-const to allow modification of the driver object
	if [ -f linux/drivers/dahdi/xpp/xpd.h ]; then
	    sed -i 's/xpd_driver_register(const struct device_driver/xpd_driver_register(struct device_driver/g' linux/drivers/dahdi/xpp/xpd.h
	    sed -i 's/xpd_driver_unregister(const struct device_driver/xpd_driver_unregister(struct device_driver/g' linux/drivers/dahdi/xpp/xpd.h
	fi
	
	if [ -f linux/drivers/dahdi/xpp/xbus-sysfs.c ]; then
	    sed -i 's/xpd_driver_register(const struct device_driver/xpd_driver_register(struct device_driver/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	    sed -i 's/xpd_driver_unregister(const struct device_driver/xpd_driver_unregister(struct device_driver/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	    sed -i 's/sync_show(const struct device_driver/sync_show(struct device_driver/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	    sed -i 's/sync_store(const struct device_driver/sync_store(struct device_driver/g' linux/drivers/dahdi/xpp/xbus-sysfs.c
	fi
	
	# 4. Remove the vpmadt032 loader (prevents objtool Error 255)
	sed -i '/dahdi_vpmadt032_loader.o/d' linux/drivers/dahdi/Kbuild
	
	# 5. Final Cleanup: Remove any "const const" caused by overlapping seds
	find linux/drivers/dahdi/ -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/const const/const/g' {} +
	
	echo "Patches applied successfully."
	echo "Now running build..."
	
	# Clean and Build
	make -C linux clean
	make all CONFIG_OBJTOOL=n
	
	if [ $? -eq 0 ]; then
	    echo "-------------------------------------------------------"
	    echo "BUILD SUCCESSFUL!"
	    echo "Run 'make install' and 'make config' to finish."
	    echo "-------------------------------------------------------"
	else
	    echo "Build failed. Check the logs above for errors."
	fi
	#####################################################################################################################################################
fi

#: ${JOBS:=$(( $(nproc) + $(nproc) / 2 ))}
: ${JOBS:=$(nproc)}
make -j ${JOBS} all
make install
make config
make install-config
#yum -y install dahdi-tools-libs
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

\cp -r /etc/systemd/system/dahdi.service /etc/systemd/system/dahdi.service.bak
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

#restart dahdi Service
systemctl daemon-reload && \
systemctl disable dahdi.service && \
systemctl enable dahdi.service && \
systemctl restart dahdi.service && \
systemctl status dahdi.service | head -n 18

\cp -r /dahdi.sh /dahdi.sh.bak
rm -rf /dahdi.sh
\cp -r  /usr/src/dahdi.sh /dahdi.sh

chmod +x /dahdi.sh 
