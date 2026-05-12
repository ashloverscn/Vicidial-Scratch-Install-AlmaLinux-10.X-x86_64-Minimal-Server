#!/bin/bash

# =========================================================
# ULTRA FAST PERL INSTALLER
# AlmaLinux 10
# Uses:
#   - DNF first
#   - cpm (FASTEST)
#   - cpanm fallback
# =========================================================

set +e

LOGFILE="/root/fast-perl-install.log"

exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "======================================="
echo " ULTRA FAST PERL INSTALLER"
echo " AlmaLinux 10"
echo "======================================="

if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

# ---------------------------------------------------------
# SYSTEM PREP
# ---------------------------------------------------------

echo "[1/7] Preparing system..."

dnf clean all

dnf install -y epel-release

dnf groupinstall -y "Development Tools"

dnf install -y \
perl perl-core perl-devel \
perl-App-cpanminus \
gcc gcc-c++ make automake autoconf libtool patch \
wget curl tar gzip unzip xz \
openssl-devel zlib-devel expat-devel \
readline-devel ncurses-devel \
libxml2-devel libxslt-devel \
perl-CPAN perl-DBI perl-JSON perl-JSON-XS \
perl-XML-Parser perl-XML-LibXML \
perl-Net-SSLeay perl-IO-Socket-SSL \
perl-Time-HiRes perl-ExtUtils-MakeMaker \
perl-Test-Simple perl-Test-Warn \
perl-Test-Exception \
tk tk-devel perl-Tk

# ---------------------------------------------------------
# FAST CPAN CLIENTS
# ---------------------------------------------------------

echo "[2/7] Installing fast CPAN clients..."

yes | cpan App::cpanminus

cpanm --notest --force App::cpm

# ---------------------------------------------------------
# ENVIRONMENT
# ---------------------------------------------------------

echo "[3/7] Configuring environment..."

export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"
export NONINTERACTIVE_TESTING=1

export HARNESS_OPTIONS=j8
export MAKEFLAGS="-j$(nproc)"

# ---------------------------------------------------------
# MODULE LIST
# ---------------------------------------------------------

MODULES=(
Capture::Tiny
Command::Runner
ExtUtils::Config
ExtUtils::Helpers
ExtUtils::InstallPaths
File::Copy::Recursive
File::pushd
HTTP::Tinyish
IPC::Run3
JSON::PP
JSON::XS
Module::CPANfile
Parallel::Pipes
Parse::PMFile
String::ShellQuote
Types::Serialiser
YAML::PP
common::sense
Class::Method::Modifiers
Crypt::Eksblowfish
Crypt::RC4
Curses
Digest::SHA1
Digest::Perl::MD5
HTML::Tree
Mail::IMAPClient
Mail::Message
Mail::POP3Client
Mail::Sendmail
Net::Server
Net::Telnet
Proc::ProcessTable
Spreadsheet::WriteExcel
Text::CSV
XML::Twig
XML::XPath
Tk::TableMatrix
String::CRC
)

# ---------------------------------------------------------
# INSTALL LOOP
# ---------------------------------------------------------

echo "[4/7] Installing modules using cpm..."

for m in "${MODULES[@]}"; do

    echo "------------------------------------------------"
    echo "MODULE: $m"

    perl -M"$m" -e 1 >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "[OK] Already installed"
        continue
    fi

    # -----------------------------------------------------
    # FAST METHOD: CPM
    # -----------------------------------------------------

    echo "[CPM] Installing..."

    cpm install \
        -g \
        --show-build-log-on-failure \
        --no-test \
        "$m"

    perl -M"$m" -e 1 >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "[OK] Installed via CPM"
        continue
    fi

    # -----------------------------------------------------
    # FALLBACK: CPANM
    # -----------------------------------------------------

    echo "[CPANM FALLBACK] Installing..."

    cpanm \
        --notest \
        --force \
        --skip-satisfied \
        "$m"

    perl -M"$m" -e 1 >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "[OK] Installed via CPANM"
        continue
    fi

    # -----------------------------------------------------
    # FINAL FALLBACK: DNF
    # -----------------------------------------------------

    echo "[DNF FALLBACK] Attempting RPM package..."

    pkg=$(echo "$m" | sed 's/::/-/g')

    dnf install -y "perl-$pkg"

    perl -M"$m" -e 1 >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "[OK] Installed via DNF"
    else
        echo "[FAIL] $m"
    fi

done

# ---------------------------------------------------------
# REHASH
# ---------------------------------------------------------

echo "[5/7] Refreshing shell..."

hash -r

# ---------------------------------------------------------
# FINAL VERIFY
# ---------------------------------------------------------

echo "[6/7] Final verification..."

FAILED=0

for m in "${MODULES[@]}"; do

    perl -M"$m" -e 1 >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "[OK] $m"
    else
        echo "[MISSING] $m"
        FAILED=1
    fi

done

# ---------------------------------------------------------
# DONE
# ---------------------------------------------------------

echo "[7/7] Completed."

echo ""
echo "======================================="
echo " FAST PERL INSTALL COMPLETE"
echo "======================================="

echo ""
echo "Log:"
echo "$LOGFILE"

if [[ $FAILED -eq 1 ]]; then
    echo ""
    echo "Some modules still failed."
else
    echo ""
    echo "All modules installed successfully."
fi
