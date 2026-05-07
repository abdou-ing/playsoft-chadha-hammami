#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-client sshpass

echo "[INFO] Installation autoattack2.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/autoattack2.sh
sudo cp /tmp/autoattack2.sh /usr/local/bin/autoattack2.sh
sudo chmod 0755 /usr/local/bin/autoattack2.sh

echo "[INFO] Création service + timer systemd..."
sudo tee /etc/systemd/system/autoattack2.service > /dev/null <<EOF
[Unit]
Description=Auto Attack Script v2
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/autoattack2.sh
User=root
Environment="PATH=/usr/bin:/bin:/usr/sbin:/sbin"
EOF

sudo tee /etc/systemd/system/autoattack2.timer > /dev/null <<EOF
[Unit]
Description=Run Auto Attack Script v2 every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=autoattack2.service
[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable autoattack2.timer
sudo systemctl start autoattack2.timer

echo "[+] config-attack.sh terminé"