#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true
sudo kill -9 $(pgrep unattended-upgr) 2>/dev/null || true
for i in $(seq 1 30); do
  sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
  echo "Lock APT occupé ($i/30)..."
  sleep 5
done
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true
sudo dpkg --configure -a || true

echo "[INFO] Installation HAProxy..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy
sudo systemctl enable haproxy

echo "[INFO] Configuration HAProxy..."
sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    option  dontlognull
    retries 3
    timeout connect 5s
    timeout client  30s
    timeout server  30s

# --- Frontend for CTFd Web App ---
frontend ctfd_frontend
    bind *:80
    mode http
    default_backend ctfd_backend

backend ctfd_backend
    mode http
    balance roundrobin
    option httpchk GET /
    server ctfd1 $MACHINE1_IP:8000 check
    server ctfd2 $MACHINE2_IP:8001 check

# --- Frontend for MariaDB ---
frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend

backend mariadb_backend
    mode tcp
    balance roundrobin
    option mysql-check user haproxy
    server db1 $MACHINE1_IP:3307 check
    server db2 $MACHINE2_IP:3308 check backup
EOF

sudo systemctl restart haproxy
sudo systemctl status haproxy --no-pager
echo "[+] HAProxy configuré ✓"