#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true
for i in $(seq 1 30); do
  sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
  echo "Lock APT occupé ($i/30)..."
  sleep 5
done
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true
sudo dpkg --configure -a || true

echo "[INFO] Installation des paquets..."
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
Description=Run fauxpositif every 5 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fauxpositif.timer
sudo systemctl start fauxpositif.timer

echo "[+] config-fauxpositif-medium.sh terminé"