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
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-client sshpass
# ─── autoattack2.sh ───────────────────────────────────────
echo "[INFO] Installation autoattack2.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/autoattack2.sh
sudo cp /tmp/autoattack2.sh /usr/local/bin/autoattack2.sh
sudo chmod 0755 /usr/local/bin/autoattack2.sh

sudo tee /etc/systemd/system/autoattack2.service > /dev/null <<SVCEOF
[Unit]
Description=Auto Attack Script v2
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/autoattack2.sh
User=root
Environment="PATH=/usr/bin:/bin:/usr/sbin:/sbin"
SVCEOF

sudo tee /etc/systemd/system/autoattack2.timer > /dev/null <<TMREOF
[Unit]
Description=Run Auto Attack Script v2 every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=autoattack2.service
[Install]
WantedBy=timers.target
TMREOF

# ─── fauxpositif.sh ──────────────────────────────────────
echo "[INFO] Installation fauxpositif.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/fauxpositif.sh
sed -i "s|__TESTUSER_PASS__|$TESTUSER_PASSWORD|g" /tmp/fauxpositif.sh
sudo cp /tmp/fauxpositif.sh /usr/local/bin/fauxpositif.sh
sudo chmod 0755 /usr/local/bin/fauxpositif.sh

sudo tee /etc/systemd/system/fauxpositif.service > /dev/null <<SVCEOF
[Unit]
Description=Faux Positif SSH Script
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/fauxpositif.sh
User=root
SVCEOF

sudo tee /etc/systemd/system/fauxpositif.timer > /dev/null <<TMREOF
[Unit]
Description=Run Faux Positif SSH Script every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=fauxpositif.service
[Install]
WantedBy=timers.target
TMREOF

# ─── legit_ssh.sh ────────────────────────────────────────
echo "[INFO] Installation legit_ssh.sh..."
sed -i "s|__AGENT_IP__|$AGENT_IP|g" /tmp/legit_ssh.sh
sed -i "s|__TESTUSER_PASS__|$TESTUSER_PASSWORD|g" /tmp/legit_ssh.sh
sudo cp /tmp/legit_ssh.sh /usr/local/bin/legit_ssh.sh
sudo chmod 0755 /usr/local/bin/legit_ssh.sh

sudo tee /etc/systemd/system/legit_ssh.service > /dev/null <<SVCEOF
[Unit]
Description=Legitimate SSH Connection Service
[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/legit_ssh.sh
User=root
SVCEOF

sudo tee /etc/systemd/system/legit_ssh.timer > /dev/null <<TMREOF
[Unit]
Description=Run Legitimate SSH Connection every 10 minutes
[Timer]
OnBootSec=60
OnUnitActiveSec=600
Unit=legit_ssh.service
[Install]
WantedBy=timers.target
TMREOF

# ─── Activer tous les timers ─────────────────────────────
echo "[INFO] Activation des timers systemd..."
sudo systemctl daemon-reload
sudo systemctl enable autoattack2.timer fauxpositif.timer legit_ssh.timer
sudo systemctl start autoattack2.timer fauxpositif.timer legit_ssh.timer

# ─── Netplan ─────────────────────────────────────────────
echo "[INFO] Configuration IP statique..."
sudo rm -f /etc/netplan/01-network-manager-all.yaml
sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml
sudo chmod 600 /etc/netplan/99-static.yaml
nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &

echo "[+] config-unified.sh terminé"
