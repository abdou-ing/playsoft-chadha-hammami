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

echo "[INFO] Installation des paquets..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sshpass openssh-client

echo "[INFO] Installation legit_ssh.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/legit_ssh.sh
sed -i "s|__TESTUSER_PASS__|$TESTUSER_PASSWORD|g" /tmp/legit_ssh.sh
sudo cp /tmp/legit_ssh.sh /usr/local/bin/legit_ssh.sh
sudo chmod 0755 /usr/local/bin/legit_ssh.sh

echo "[INFO] Création service + timer systemd..."
sudo tee /etc/systemd/system/legit_ssh.service > /dev/null <<EOF
[Unit]
Description=Legitimate SSH Connection Service
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/legit_ssh.sh
User=root
EOF

sudo tee /etc/systemd/system/legit_ssh.timer > /dev/null <<EOF
[Unit]
Description=Run Legitimate SSH Connection every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=legit_ssh.service
[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable legit_ssh.timer
sudo systemctl start legit_ssh.timer

echo "[+] config-legit.sh terminé"