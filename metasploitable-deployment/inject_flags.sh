#!/bin/bash
# =============================================================================
# inject_flags.sh - CTF Flag Injection Script for Metasploitable2
# =============================================================================
# Called by Packer during the build phase.
# Flags are passed via environment variables defined in Packer variables.
#
# All commands below have been tested manually on the target machine.
#
# Services:
#   SSH        -> /opt/flag/.flag.txt
#   FTP        -> /home/ftp/ftp-flag.txt
#   SMB        -> /tmp/smb-flag.txt
#   HTTP       -> /var/www/test/testoutput/.config.php  (PHP comment)
#   Telnet     -> /etc/issue.net                        (banner)
#   MySQL      -> ctf.sql_flag table
#   PostgreSQL -> postgres.sql_flag table
# =============================================================================

set -e

echo "[*] Starting CTF flag injection..."
echo ""

# -----------------------------------------------------------------------
# SSH FLAG
# /opt/flag/.flag.txt (hidden file inside /opt/flag/)
# Student must: SSH in → navigate /opt → find hidden .flag.txt
# -----------------------------------------------------------------------
echo "[+] Injecting SSH flag..."
mkdir -p /opt/flag
echo "${FLAG_SSH}" | sudo tee /opt/flag/.flag.txt > /dev/null
chmod 644 /opt/flag/.flag.txt
echo "    -> Written to /opt/flag/.flag.txt"

# -----------------------------------------------------------------------
# FTP FLAG
# /home/ftp/ftp-flag.txt (accessible via anonymous FTP)
# -----------------------------------------------------------------------
echo "[+] Injecting FTP flag..."
mkdir -p /home/ftp
echo "${FLAG_FTP}" | sudo tee /home/ftp/ftp-flag.txt > /dev/null
chmod 644 /home/ftp/ftp-flag.txt
echo "    -> Written to /home/ftp/ftp-flag.txt"

# -----------------------------------------------------------------------
# SMB FLAG
# /tmp/smb-flag.txt (accessible via Samba null session)
# -----------------------------------------------------------------------
echo "[+] Injecting SMB flag..."
echo "${FLAG_SMB}" | sudo tee /tmp/smb-flag.txt > /dev/null
chmod 644 /tmp/smb-flag.txt
echo "    -> Written to /tmp/smb-flag.txt"

# -----------------------------------------------------------------------
# HTTP FLAG
# /var/www/test/testoutput/.config.php
# Flag is in a PHP comment → invisible in browser render.
# Student needs a www-data shell and must use ls -la to find hidden file.
# -----------------------------------------------------------------------
echo "[+] Injecting HTTP flag..."
mkdir -p /var/www/test/testoutput
echo "<?php /* ${FLAG_HTTP} */ ?>" | sudo tee /var/www/test/testoutput/.config.php > /dev/null
chmod 644 /var/www/test/testoutput/.config.php
chown www-data:www-data /var/www/test/testoutput/.config.php 2>/dev/null || true
echo "    -> Written to /var/www/test/testoutput/.config.php"

# -----------------------------------------------------------------------
# TELNET FLAG
# /etc/issue.net → displayed automatically as Telnet pre-login banner.
# SSH does NOT show this file (no Banner directive in sshd_config).
# Student must connect via Telnet port 23 to see the flag.
# -----------------------------------------------------------------------
echo "[+] Injecting Telnet banner flag..."
echo "<?php /* ${FLAG_TELNET} */ ?>" | sudo tee /etc/issue.net > /dev/null
chmod 644 /etc/issue.net
echo "    -> Written to /etc/issue.net (Telnet banner)"

# Make sure SSH does NOT expose this banner
if grep -q "^Banner" /etc/ssh/sshd_config; then
  sed -i 's|^Banner.*|#Banner none|' /etc/ssh/sshd_config
fi

# -----------------------------------------------------------------------
# MYSQL FLAG
# Database: ctf  |  Table: sql_flag
# Student connects: mysql -h <IP> -P 3306 -u root --skip-ssl
# Then: USE ctf; SELECT * FROM sql_flag;
# -----------------------------------------------------------------------
echo "[+] Injecting MySQL flag..."
mysql -h 127.0.0.1 -P 3306 -u root --skip-ssl 2>/dev/null <<SQLEOF
CREATE DATABASE IF NOT EXISTS ctf;
USE ctf;
DROP TABLE IF EXISTS sql_flag;
CREATE TABLE sql_flag (flag VARCHAR(255));
INSERT INTO sql_flag VALUES ('${FLAG_MYSQL}');
SQLEOF
echo "    -> Inserted into MySQL: ctf.sql_flag"

# -----------------------------------------------------------------------
# POSTGRESQL FLAG
# Database: postgres  |  Table: sql_flag
# Student connects: psql -h <IP> -p 5432 -U postgres -d template1
# Then: \c postgres  →  SELECT * FROM sql_flag;
# Password: postgres
# -----------------------------------------------------------------------
echo "[+] Injecting PostgreSQL flag..."
export PGPASSWORD="postgres"
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres 2>/dev/null <<PGEOF
DROP TABLE IF EXISTS sql_flag;
CREATE TABLE sql_flag (flag TEXT);
INSERT INTO sql_flag VALUES ('${FLAG_POSTGRES}');
PGEOF
unset PGPASSWORD
echo "    -> Inserted into PostgreSQL: postgres.sql_flag"

# -----------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------
echo ""
echo "[*] ================================================"
echo "[*]  All CTF flags injected successfully!"
echo "[*] ================================================"
echo "[*]  SSH        -> /opt/flag/.flag.txt"
echo "[*]  FTP        -> /home/ftp/ftp-flag.txt"
echo "[*]  SMB        -> /tmp/smb-flag.txt"
echo "[*]  HTTP       -> /var/www/test/testoutput/.config.php"
echo "[*]  Telnet     -> /etc/issue.net (banner)"
echo "[*]  MySQL      -> ctf.sql_flag"
echo "[*]  PostgreSQL -> postgres.sql_flag"
echo "[*] ================================================"
