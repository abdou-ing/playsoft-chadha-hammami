#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo kill -9 $(pgrep unattended-upgr) 2>/dev/null || true
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Attente lock dpkg...'; sleep 3; done
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
sudo dpkg --configure -a || true
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sshpass openssh-client

echo "[INFO] Installation fauxpositif.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/fauxpositif.sh
sed -i "s|__TESTUSER_PASS__|$TESTUSER_PASSWORD|g" /tmp/fauxpositif.sh
sudo cp /tmp/fauxpositif.sh /usr/local/bin/fauxpositif.sh
sudo chmod 0755 /usr/local/bin/fauxpositif.sh

echo "[INFO] Création service + timer systemd..."
sudo tee /etc/systemd/system/fauxpositif.service > /dev/null <<EOF
[Unit]
Description=Faux Positif SSH Script
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/fauxpositif.sh
User=root
EOF

sudo tee /etc/systemd/system/fauxpositif.timer > /dev/null <<EOF
[Unit]
Description=Run Faux Positif SSH Script every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=fauxpositif.service
[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fauxpositif.timer
sudo systemctl start fauxpositif.timer


echo "[INFO] Configuration IP statique..."
sudo rm -f /etc/netplan/01-network-manager-all.yaml
sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml
sudo chmod 600 /etc/netplan/99-static.yaml
nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &

echo "[+] config-faux-positif.sh terminé"

