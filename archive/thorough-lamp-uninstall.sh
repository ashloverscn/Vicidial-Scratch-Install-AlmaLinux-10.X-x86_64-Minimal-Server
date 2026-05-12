#!/bin/bash

# =====================================================================
# THOROUGH LAMP STACK UNINSTALLER
# AlmaLinux / RockyLinux / RHEL 8 & 9
# =====================================================================
#
# Removes COMPLETELY:
# - Apache/httpd
# - Nginx
# - PHP + PHP-FPM + modules
# - MariaDB/MySQL
# - phpMyAdmin
# - configs in /etc
# - logs
# - databases
# - sockets
# - cache
# - users/groups
# - systemd units
# - cron remnants
# - SELinux contexts
#
# PURPOSE:
# Create a CLEAN SERVER STATE for reinstall.
#
# WARNING:
# THIS DELETES DATABASES AND WEB DATA PERMANENTLY.
#
# =====================================================================

set +e

LOGFILE="/root/lamp-uninstall-$(date +%F-%H%M%S).log"

exec > >(tee -a "$LOGFILE")
exec 2>&1

clear

echo "==================================================="
echo " THOROUGH LAMP STACK UNINSTALLER "
echo "==================================================="
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

sleep 2

# ---------------------------------------------------------------------
# DETECT PACKAGES
# ---------------------------------------------------------------------

echo "[1/20] Detecting installed LAMP components..."

LAMP_PKGS=$(rpm -qa | egrep -i \
'httpd|apache|nginx|php|mariadb|mysql|phpMyAdmin|mod_ssl|mysql-shell|mysql-router')

echo ""
echo "Detected packages:"
echo "---------------------------------------------------"
echo "$LAMP_PKGS"
echo "---------------------------------------------------"

sleep 2

# ---------------------------------------------------------------------
# STOP SERVICES
# ---------------------------------------------------------------------

echo "[2/20] Stopping services..."

SERVICES=(
httpd
nginx
mariadb
mysqld
php-fpm
)

for svc in "${SERVICES[@]}"; do
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
done

# ---------------------------------------------------------------------
# KILL PROCESSES
# ---------------------------------------------------------------------

echo "[3/20] Killing remaining processes..."

PROCS=(
httpd
nginx
mysqld
mariadbd
php-fpm
)

for p in "${PROCS[@]}"; do
    pkill -9 -f "$p" 2>/dev/null
done

# ---------------------------------------------------------------------
# REMOVE RPM PACKAGES
# ---------------------------------------------------------------------

echo "[4/20] Removing RPM packages..."

dnf remove -y \
httpd* \
apache* \
nginx* \
php* \
mariadb* \
mysql* \
phpMyAdmin* \
mod_* \
mysql-shell* \
mysql-router* \
mysql-community* \
php-fpm* \
php-cli* \
php-common* \
php-gd* \
php-mbstring* \
php-pdo* \
php-mysqlnd* \
php-xml* \
php-opcache* \
php-devel* \
php-pear* \
php-pecl* || true

# ---------------------------------------------------------------------
# REMOVE MODULE STREAMS
# ---------------------------------------------------------------------

echo "[5/20] Resetting DNF module streams..."

dnf module reset php -y 2>/dev/null
dnf module reset mysql -y 2>/dev/null

# ---------------------------------------------------------------------
# REMOVE CONFIGS
# ---------------------------------------------------------------------

echo "[6/20] Removing configuration files..."

rm -rf /etc/httpd
rm -rf /etc/nginx
rm -rf /etc/php*
rm -rf /etc/my.cnf
rm -rf /etc/my.cnf.d

# ---------------------------------------------------------------------
# REMOVE WEB DATA
# ---------------------------------------------------------------------

echo "[7/20] Removing web directories..."

rm -rf /var/www
rm -rf /srv/www
rm -rf /usr/share/nginx
rm -rf /usr/share/httpd

# ---------------------------------------------------------------------
# REMOVE DATABASES
# ---------------------------------------------------------------------

echo "[8/20] Removing database files..."

rm -rf /var/lib/mysql
rm -rf /var/lib/mysql-files
rm -rf /var/lib/php
rm -rf /var/lib/phpMyAdmin

# ---------------------------------------------------------------------
# REMOVE LOGS
# ---------------------------------------------------------------------

echo "[9/20] Removing logs..."

rm -rf /var/log/httpd
rm -rf /var/log/nginx
rm -rf /var/log/mysql*
rm -rf /var/log/mariadb*
rm -rf /var/log/php*
rm -rf /var/log/php-fpm*

# ---------------------------------------------------------------------
# REMOVE CACHE
# ---------------------------------------------------------------------

echo "[10/20] Removing cache..."

rm -rf /var/cache/httpd
rm -rf /var/cache/nginx
rm -rf /var/cache/php*
rm -rf /var/cache/mysql*

# ---------------------------------------------------------------------
# REMOVE SOCKETS / RUNTIME
# ---------------------------------------------------------------------

echo "[11/20] Removing runtime files..."

rm -rf /run/httpd
rm -rf /run/nginx
rm -rf /run/php-fpm
rm -rf /run/mariadb
rm -rf /var/run/mariadb

find /run -iname "*mysql*" -delete 2>/dev/null
find /run -iname "*php*" -delete 2>/dev/null

# ---------------------------------------------------------------------
# REMOVE USERS/GROUPS
# ---------------------------------------------------------------------

echo "[12/20] Removing system users/groups..."

USERS=(
apache
mysql
nginx
)

for u in "${USERS[@]}"; do
    userdel -r "$u" 2>/dev/null
done

for g in "${USERS[@]}"; do
    groupdel "$g" 2>/dev/null
done

# ---------------------------------------------------------------------
# REMOVE SYSTEMD REMNANTS
# ---------------------------------------------------------------------

echo "[13/20] Removing systemd remnants..."

find /etc/systemd -iname "*httpd*" -delete
find /etc/systemd -iname "*nginx*" -delete
find /etc/systemd -iname "*mysql*" -delete
find /etc/systemd -iname "*php*" -delete

find /usr/lib/systemd -iname "*httpd*" -delete
find /usr/lib/systemd -iname "*nginx*" -delete
find /usr/lib/systemd -iname "*mysql*" -delete
find /usr/lib/systemd -iname "*php*" -delete

systemctl daemon-reexec
systemctl daemon-reload
systemctl reset-failed

# ---------------------------------------------------------------------
# REMOVE CRON JOBS
# ---------------------------------------------------------------------

echo "[14/20] Removing cron remnants..."

find /etc/cron* -iname "*php*" -delete
find /etc/cron* -iname "*mysql*" -delete
find /etc/cron* -iname "*httpd*" -delete

# ---------------------------------------------------------------------
# FIREWALL CLEANUP
# ---------------------------------------------------------------------

echo "[15/20] Removing firewall services..."

firewall-cmd --permanent --remove-service=http 2>/dev/null
firewall-cmd --permanent --remove-service=https 2>/dev/null
firewall-cmd --reload 2>/dev/null

# ---------------------------------------------------------------------
# DEEP FILESYSTEM PURGE
# ---------------------------------------------------------------------

echo "[16/20] Deep filesystem scan cleanup..."

find /etc -iname "*php*" -exec rm -rf {} \; 2>/dev/null
find /etc -iname "*mysql*" -exec rm -rf {} \; 2>/dev/null
find /etc -iname "*mariadb*" -exec rm -rf {} \; 2>/dev/null
find /etc -iname "*httpd*" -exec rm -rf {} \; 2>/dev/null
find /etc -iname "*nginx*" -exec rm -rf {} \; 2>/dev/null

# ---------------------------------------------------------------------
# CLEAN DNF
# ---------------------------------------------------------------------

echo "[17/20] Cleaning DNF..."

dnf autoremove -y
dnf clean all

rm -rf /var/cache/dnf/*

# ---------------------------------------------------------------------
# CLEAN TEMP
# ---------------------------------------------------------------------

echo "[18/20] Cleaning temp files..."

rm -rf /tmp/*
rm -rf /var/tmp/*

# ---------------------------------------------------------------------
# VERIFY REMAINING PACKAGES
# ---------------------------------------------------------------------

echo "[19/20] Verifying leftovers..."

echo ""
echo "Remaining LAMP packages:"
rpm -qa | egrep -i \
'httpd|apache|nginx|php|mysql|mariadb'

echo ""
echo "Remaining LAMP configs:"
find /etc | egrep \
'httpd|nginx|php|mysql|mariadb'

# ---------------------------------------------------------------------
# FINAL STATUS
# ---------------------------------------------------------------------

echo "[20/20] Final system status..."

echo ""
echo "Listening services:"
ss -tulpn

echo ""
echo "Disk usage:"
df -h

echo ""
echo "==================================================="
echo " THOROUGH LAMP UNINSTALL COMPLETE "
echo "==================================================="
echo ""
echo "Log file:"
echo "$LOGFILE"
echo ""
echo "Recommended:"
echo "reboot"
echo ""
