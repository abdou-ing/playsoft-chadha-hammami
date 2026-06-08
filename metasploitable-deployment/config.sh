#!/bin/bash
# config.sh — Metasploitable CTF flag injection

chmod +x /tmp/inject_flags.sh

echo msfadmin | sudo -S env \
  FLAG_SSH="$FLAG_SSH" \
  FLAG_FTP="$FLAG_FTP" \
  FLAG_SMB="$FLAG_SMB" \
  FLAG_HTTP="$FLAG_HTTP" \
  FLAG_TELNET="$FLAG_TELNET" \
  FLAG_MYSQL="$FLAG_MYSQL" \
  FLAG_POSTGRES="$FLAG_POSTGRES" \
  /tmp/inject_flags.sh

echo msfadmin | sudo -S shutdown -h now || true