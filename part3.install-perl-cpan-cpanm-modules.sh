#!/bin/bash

set -e

echo "=============================="
echo " HYBRID PERL INSTALLER (DNF + CPAN)"
echo "=============================="

# ----------------------------
# 1. SYSTEM DEPENDENCIES (FAST PATH)
# ----------------------------

echo "[1/3] Installing system dependencies via dnf..."

dnf groupinstall "Development Tools" -y

dnf install -y \
perl perl-core perl-devel perl-App-cpanminus \
gcc gcc-c++ make autoconf automake libtool patch \
tk tk-devel perl-Tk \
libX11-devel libXpm-devel libXft-devel libXext-devel \
openssl-devel zlib-devel expat-devel \
perl-DBI perl-JSON perl-JSON-XS perl-Text-CSV \
perl-XML-Parser perl-XML-LibXML perl-Digest-SHA \
perl-Digest-MD5 perl-Net-SSLeay perl-IO-Socket-SSL \
perl-Time-HiRes perl-File-Copy-Recursive \
perl-ExtUtils-MakeMaker perl-CPAN

echo "[OK] DNF base dependencies installed"

# ----------------------------
# 2. MODULE LIST
# ----------------------------

MODULES=(
App::cpanminus
App::cpm
CPAN
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
Tk
Tk::TableMatrix
String::CRC
)

# ----------------------------
# 3. INSTALL LOGIC
# ----------------------------

echo "[2/3] Checking modules..."

for m in "${MODULES[@]}"; do
    perl -M"$m" -e 1 >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "[OK] Already installed: $m"
        continue
    fi

    # Try CPAN first
    echo "[CPAN] Installing: $m"
    cpanm --notest "$m"

    if [ $? -ne 0 ]; then
        echo "[DNF FALLBACK] Trying system package for $m"

        # convert Perl::Module → perl-Module format (best effort)
        pkg=$(echo "$m" | tr '[:upper:]' '[:lower:]' | sed 's/::/-/g')
        dnf install -y "perl-$pkg" || echo "[SKIP] No dnf package: $m"
    fi

done

# ----------------------------
# 4. FINAL VERIFICATION
# ----------------------------

echo "[3/3] Final verification..."

for m in "${MODULES[@]}"; do
    perl -M"$m" -e 1 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] $m"
    else
        echo "[FAIL] $m"
    fi
done

echo "=============================="
echo " INSTALLATION COMPLETE"
echo "=============================="
