#!/bin/bash

# codec-install.sh (UPDATED FOR ASTERISK 20.x)
# VICIdial / Asterisk hosting.lv codec installer
# Updated for Asterisk 18–20 compatibility

CPUNAME="$(cut -d':' -f2 <<<$(cat /proc/cpuinfo | grep 'model name' | sed -n 1p))"
CPUVEN="$(cut -d':' -f2 <<<$(cat /proc/cpuinfo | grep 'vendor' | sed -n 1p))"
CPUFAM="$(cut -d':' -f2 <<<$(cat /proc/cpuinfo | grep 'family' | sed -n 1p))"
CPUFLAG="$(cut -d':' -f2 <<<$(cat /proc/cpuinfo | grep 'flags' | sed -n 1p))"

G729='codec_g729-'
G723='codec_g723-'

OSARCH='gcc4-glibc-x86_64-'
ASTVER=''
CPUARCH=''

URL='http://asterisk.hosting.lv/bin/'
FQDN="$(cut -d'/' -f3 <<<$URL)"

SRCDIR='/usr/src/astguiclient/conf/codecs/'
MODDIR='/usr/lib64/asterisk/modules/'
AST_BIN=/usr/sbin/asterisk

# -------------------------
# CHECK ASTERISK
# -------------------------
if [ ! -x $AST_BIN ]; then
  echo "No Asterisk found at $AST_BIN"
  exit 1
fi

if [ ! -d $MODDIR ]; then
  echo "No module directory at $MODDIR"
  exit 1
fi

echo "--- Asterisk Codec Installer (UPDATED FOR 20.x) ---"
echo

# -------------------------
# ASTERISK VERSION DETECT
# -------------------------
RAWASTVER=`$AST_BIN -V`
ASTVERSION=$(echo $RAWASTVER | awk '{print $2}')

echo "Detected Asterisk: $ASTVERSION"

if [[ $ASTVERSION =~ ^20 ]]; then
  ASTVER="ast200-"
elif [[ $ASTVERSION =~ ^19 ]]; then
  ASTVER="ast190-"
elif [[ $ASTVERSION =~ ^18 ]]; then
  ASTVER="ast180-"
elif [[ $ASTVERSION =~ ^17 ]]; then
  ASTVER="ast170-"
elif [[ $ASTVERSION =~ ^16 ]]; then
  ASTVER="ast160-"
elif [[ $ASTVERSION =~ ^15 ]]; then
  ASTVER="ast150-"
elif [[ $ASTVERSION =~ ^14 ]]; then
  ASTVER="ast140-"
elif [[ $ASTVERSION =~ ^13 ]]; then
  ASTVER="ast130-"
elif [[ $ASTVERSION =~ ^12 ]]; then
  ASTVER="ast120-"
elif [[ $ASTVERSION =~ ^11 ]]; then
  ASTVER="ast110-"
elif [[ $ASTVERSION =~ ^1\.8 ]]; then
  ASTVER="ast18-"
else
  echo "Unsupported Asterisk version: $ASTVERSION"
  exit 1
fi

# -------------------------
# CPU DETECTION (SIMPLIFIED SAFE)
# -------------------------
echo "Detecting CPU..."

if [[ "$CPUVEN" == *"AMD"* ]]; then
  if [[ "$CPUFLAG" == *"sse3"* ]]; then
    CPUARCH="opteron-sse3.so"
  else
    CPUARCH="opteron.so"
  fi

elif [[ "$CPUVEN" == *"Intel"* ]]; then
  if [[ "$CPUFLAG" == *"sse4"* ]]; then
    CPUARCH="core2-sse4.so"
  else
    CPUARCH="core2.so"
  fi
else
  echo "Unsupported CPU vendor: $CPUVEN"
  exit 1
fi

echo "CPU module: $CPUARCH"

# -------------------------
# ONLINE CHECK
# -------------------------
ping -c2 $FQDN >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "Offline mode - using local codec files"

  if [ -f $SRCDIR$G729$ASTVER$OSARCH$CPUARCH ]; then
    cp $SRCDIR$G729$ASTVER$OSARCH$CPUARCH $MODDIR/codec_g729.so
  fi

  if [ -f $SRCDIR$G723$ASTVER$OSARCH$CPUARCH ]; then
    cp $SRCDIR$G723$ASTVER$OSARCH$CPUARCH $MODDIR/codec_g723.so
  fi

else
  echo "Downloading codecs from hosting.lv"

  cd /tmp
  rm -f codec_g72*

  # G729
  wget -q $URL$G729$ASTVER$OSARCH$CPUARCH
  if [ $? -eq 0 ]; then
    mv -f $G729$ASTVER$OSARCH$CPUARCH $MODDIR/codec_g729.so
    echo "G729 installed"
  fi

  # G723
  wget -q $URL$G723$ASTVER$OSARCH$CPUARCH
  if [ $? -eq 0 ]; then
    mv -f $G723$ASTVER$OSARCH$CPUARCH $MODDIR/codec_g723.so
    echo "G723 installed"
  fi
fi

# -------------------------
# LOAD INTO ASTERISK (20.x SAFE METHOD)
# -------------------------
ASTERISK_PS=$(ps ax | grep asterisk | grep -v grep)

if [[ $ASTERISK_PS ]]; then
  echo "Reloading codecs in Asterisk..."

  if [ -f $MODDIR/codec_g729.so ]; then
    $AST_BIN -rx "module load codec_g729.so" >/dev/null 2>&1
  fi

  if [ -f $MODDIR/codec_g723.so ]; then
    $AST_BIN -rx "module load codec_g723.so" >/dev/null 2>&1
  fi
else
  echo "Asterisk not running - skipping module load"
fi

echo "Codec installation complete"
